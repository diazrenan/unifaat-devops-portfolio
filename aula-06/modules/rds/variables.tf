variable "db_name" {
  description = "Nome do database"
  type        = string
}

variable "db_username" {
  description = "Usuário master do banco de dados"
  type        = string
}

variable "db_password" {
  description = "Senha master do banco de dados"
  type        = string
  sensitive   = true
}

variable "subnet_ids" {
  description = "Lista de IDs de subnets privadas para o DB Subnet Group"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Lista de IDs dos Security Groups associados à instância RDS"
  type        = list(string)
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "allocated_storage" {
  description = "Armazenamento alocado em GB"
  type        = number
  default     = 20
}
