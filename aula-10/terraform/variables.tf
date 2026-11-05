variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "O environment deve ser: dev, staging ou prod."
  }
}

variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos"
  type        = string
  default     = "technova"
}

variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block da subnet pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"   # free-tier — compatível com AWS Academy
}

variable "app_port" {
  description = "Porta em que a aplicação escuta"
  type        = number
  default     = 3000
}
