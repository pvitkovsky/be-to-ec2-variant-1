output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.example_server.id
}

output "public_ip" {
  description = "The public IP address of the Elastic IP"
  value       = aws_eip.example_eip.public_ip
}

output "public_dns" {
  description = "The public DNS name of the EC2 instance"
  value       = aws_instance.example_server.public_dns
}