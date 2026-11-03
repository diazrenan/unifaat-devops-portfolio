output "vpc_id" {
  description = "ID da VPC principal"
  value       = aws_vpc.main.id
}

output "rds_endpoint" {
  description = "Endpoint completo do RDS (host:porta)"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "Hostname do RDS"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "Porta do RDS"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "Nome do banco de dados RDS"
  value       = aws_db_instance.main.db_name
}

output "ec2_public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.app.public_ip
}

output "rds_connection_string" {
  description = "String de conexão PostgreSQL (sem senha)"
  value       = "postgresql://${aws_db_instance.main.username}@${aws_db_instance.main.address}:${aws_db_instance.main.port}/${aws_db_instance.main.db_name}"
}
