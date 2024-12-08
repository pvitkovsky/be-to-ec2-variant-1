provider "aws" {
  profile = "reminders-stage"
  region  = "eu-west-1"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "template-ec2-key"     
  public_key = file("~/.ssh/template-ec2-key.pub") 
}

# resource "aws_security_group" "syncz-sg" {
#   name        = "syncz-sg"
#   description = "Allow HTTP, SSH and ICMP"
#   vpc_id      = aws_vpc.main_vpc.id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
#   }

#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] 
#   }

#   ingress {
#     from_port   = 8080
#     to_port     = 8080
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"] 
#   }
  
#   ingress {
#     from_port   = -1
#     to_port     = -1
#     protocol    = "icmp"
#     cidr_blocks = ["0.0.0.0/0"] # Allow ping from anywhere
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
#   }
# } # TODO: needs VPCs

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

# TODO: IAM role, allowed to go to S3
# TODO: 

##### EC2 Instance #####
resource "aws_instance" "example_server" {
  ami           = "ami-02141377eee7defb9" 
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name
  # security_groups = [aws_security_group.syncz-sg.name] 
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  # Provisioning the JAR application
  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y java-17-amazon-corretto
              echo "Java Version: $(java -version)"
              mkdir /home/ec2-user/app 
              # TODO: add IAM role, or wont work;
              aws s3 cp s3://${var.s3_bucket_name}/${var.jar_file_name} /home/ec2-user/app/app.jar
              nohup java -jar /home/ec2-user/app/app.jar > /home/ec2-user/app/app.log 2>&1 &
              EOT

  tags = {
    Name = "Template Deploy Instance"
  }
}
