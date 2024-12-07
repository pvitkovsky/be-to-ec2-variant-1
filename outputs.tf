output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.example_server.id
}

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.example_server.public_ip
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance"
  value       = aws_instance.example_server.public_dns
}

output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.syncz.id
}

output "security_group_id" {
  description = "The ID of the Security Group"
  value       = aws_security_group.my_sg.id
}

output "subnet_id" {
  description = "The ID of the Subnet"
  value       = aws_subnet.subnet.id
}
