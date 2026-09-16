output "vpc_id" {
  description = "ID da VPC TechNova"
  value       = aws_vpc.technova.id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "api_security_group_id" {
  description = "ID do Security Group da API"
  value       = aws_security_group.api.id
}

output "db_security_group_id" {
  description = "ID do Security Group do banco"
  value       = aws_security_group.db.id
}

output "ec2_public_ip" {
  description = "IP público da EC2"
  value       = aws_instance.api.public_ip
}

output "api_url" {
  description = "URL da API"
  value       = "http://${aws_instance.api.public_ip}:3000"
}

output "ssh_command" {
  description = "Comando SSH para acessar a EC2"
  value       = "ssh -i ~/.ssh/technova-key ec2-user@${aws_instance.api.public_ip}"
}