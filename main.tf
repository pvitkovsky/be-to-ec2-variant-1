provider "aws" {
  profile = "reminders-stage"
  region  = "eu-west-1"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "template-ec2-key"     
  public_key = file("~/.ssh/template-ec2-key.pub") 
}


# VPC
resource "aws_vpc" "syncz_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Template Deploy Environment"
  }
}

# Subnet
resource "aws_subnet" "syncz_public_subnet" {
  vpc_id                  = aws_vpc.syncz_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Template Deploy Environment"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.syncz_vpc.id
  tags = {
    Name = "Template Deploy Environment"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.syncz_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Template Deploy Environment"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.syncz_public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "syncz-sg" {
  name        = "syncz-sg"
  description = "Allow HTTP, SSH and ICMP"
  vpc_id      = aws_vpc.syncz_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"] # Allow ping from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }
} 

# IAM Role
resource "aws_iam_role" "s3_access_role" {
  name = "template-ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Environment = "TerraformManaged"
  }
}

# IAM Policy for S3 Access
resource "aws_iam_policy" "s3_access_policy" {
  name        = "template-ec2-s3-access-policy"
  description = "Allow EC2 instance to access the specified S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${var.s3_bucket_name}",
          "arn:aws:s3:::${var.s3_bucket_name}/*"
        ]
      }
    ]
  })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.s3_access_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "template-ec2-instance-profile"
  role = aws_iam_role.s3_access_role.name
}


##### EC2 Instance #####
# TODO: private IP? 
resource "aws_instance" "example_server" {
  ami           = "ami-02141377eee7defb9" 
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name
  subnet_id     = aws_subnet.syncz_public_subnet.id
  vpc_security_group_ids = [aws_security_group.syncz-sg.id] 
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  # Provisioning the JAR application
  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y java-17-amazon-corretto
              echo "Java Version: $(java -version)"
              mkdir /home/ec2-user/app 
              aws s3 cp s3://${var.s3_bucket_name}/${var.jar_file_name} /home/ec2-user/app/app.jar
              nohup java -jar /home/ec2-user/app/app.jar > /home/ec2-user/app/app.log 2>&1 &
              EOT

  tags = {
    Name = "Template Deploy Instance"
  }
}

resource "aws_eip" "example_eip" {
  instance = aws_instance.example_server.id
}

# DNS 
data "aws_route53_zone" "fortunate_work" {
  name         = "stage.fortunate.work"
  private_zone = false
}

resource "aws_route53_record" "ec2_record" {
  zone_id =  data.aws_route53_zone.fortunate_work.zone_id
  name    = "example.deploy.stage.fortunate.work"
  type    = "A"
  ttl     = 300
  records = [aws_eip.example_eip.public_ip]
}

# TODO: https://www.whatsmydns.net/#A/example.deploy.stage.fortunate.work
# To WBS - create hosted zone a.domain.com in child org, and add NS record to domain.com at parent with NS type and 4 servers of a.
# TODO: next probably CI/CD with GitHub here because would want to add authorisation, and that relies on Java;