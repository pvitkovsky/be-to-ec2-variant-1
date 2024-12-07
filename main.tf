provider "aws" {
  profile = "reminders-stage"
  region  = "eu-west-1"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "template-ec2-key"     
  public_key = file("~/.ssh/id_rsa.pub") 
}
# TODO: template-ec2-key.pem where?
# TODO: unaccessible anywhere; 

##### VPC Creation #####
resource "aws_vpc" "syncz" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "Template Deploy VPC"
  }
}

##### Subnet Creation #####
resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.syncz.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "Template Deploy Subnet"
  }
}

##### Internet Gateway #####
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.syncz.id
  tags = {
    Name = "Template Deploy IGW"
  }
}

##### Route Table #####
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.syncz.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Template Deploy Route Table"
  }
}

##### Route Table Association #####
resource "aws_route_table_association" "route_table_assoc" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

##### Security Group #####
resource "aws_security_group" "my_sg" {
  name        = "template-ec2-be-security-group"
  description = "Allow inbound SSH and HTTP traffic"
  vpc_id      = aws_vpc.syncz.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Template EC2 BE Security Group"
  }
}

##### EC2 Instance #####
resource "aws_instance" "example_server" {
  ami           = "ami-02141377eee7defb9" 
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.subnet.id
  key_name      = aws_key_pair.my_key_pair.key_name

  # Provisioning the JAR application
  user_data = <<-EOT
              #!/bin/bash
              yum update -y
              yum install -y java-11-amazon-corretto
              echo "Java Version: $(java -version)"
              mkdir /home/ec2-user/app
              aws s3 cp s3://${var.s3_bucket_name}/${var.jar_file_name} /home/ec2-user/app/app.jar
              nohup java -jar /home/ec2-user/app/app.jar > /home/ec2-user/app/app.log 2>&1 &
              EOT

  tags = {
    Name = "Template Deploy Instance"
  }
}
