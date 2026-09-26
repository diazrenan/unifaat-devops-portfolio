output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnet_ids
}

output "api_sg_id" {
  description = "ID do Security Group da API"
  value       = module.api_sg.sg_id
}

output "rds_sg_id" {
  description = "ID do Security Group do RDS"
  value       = module.rds_sg.sg_id
}

output "api_server_instance_id" {
  description = "ID da instância EC2 do servidor de API"
  value       = module.api_server.instance_id
}

output "api_server_public_ip" {
  description = "IP público do servidor de API"
  value       = module.api_server.public_ip
}

output "database_endpoint" {
  description = "Endpoint de conexão do banco de dados"
  value       = module.database.db_endpoint
}

output "database_port" {
  description = "Porta do banco de dados"
  value       = module.database.db_port
}

output "database_name" {
  description = "Nome do banco de dados"
  value       = module.database.db_name
}
