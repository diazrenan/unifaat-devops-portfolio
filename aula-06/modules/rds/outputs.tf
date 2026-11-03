output "db_endpoint" {
  description = "Endpoint de conexão do banco de dados"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "Nome do banco de dados"
  value       = aws_db_instance.main.db_name
}

output "db_port" {
  description = "Porta do banco de dados"
  value       = aws_db_instance.main.port
}
