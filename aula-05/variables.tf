variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado para nomear os recursos"
  type        = string
  default     = "technova"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC principal"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_username" {
  description = "Usuário administrador do banco de dados RDS"
  type        = string
  default     = "technova_admin"
}

variable "db_password" {
  description = "Senha do usuário administrador do banco de dados RDS"
  type        = string
  sensitive   = true
  # Sem valor padrão — obrigatória, passada via variável de ambiente ou prompt
}

variable "db_name" {
  description = "Nome do banco de dados inicial do RDS"
  type        = string
  default     = "technova"
}
