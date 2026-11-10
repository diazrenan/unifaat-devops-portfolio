output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "subnet_public_id" {
  description = "ID da subnet pública"
  value       = aws_subnet.public.id
}

output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.app.public_ip
}

output "instance_public_dns" {
  description = "DNS público da instância EC2"
  value       = aws_instance.app.public_dns
}

output "app_url" {
  description = "URL de acesso à aplicação"
  value       = "http://${aws_instance.app.public_ip}:${var.app_port}"
}

output "security_group_id" {
  description = "ID do Security Group da aplicação"
  value       = aws_security_group.app.id
}
