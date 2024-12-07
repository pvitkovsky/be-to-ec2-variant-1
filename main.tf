provider "aws" {
  profile = "reminders-stage"
  region  = "eu-west-1"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "template-ec2-key"     
  public_key = file("~/.ssh/template-ec2-key.pub") 
}
# TODO: add to security group: SSH, HTTP and ICMP protocols;; 

##### EC2 Instance #####
resource "aws_instance" "example_server" {
  ami           = "ami-02141377eee7defb9" 
  instance_type = "t2.micro"
  key_name      = aws_key_pair.my_key_pair.key_name

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
