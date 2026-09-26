variable "name" {
  description = "Nome do Security Group"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o Security Group será criado"
  type        = string
}

variable "ingress_rules" {
  description = "Lista de regras de entrada"
  type = list(object({
    description     = string
    from_port       = number
    to_port         = number
    protocol        = string       # "tcp", "udp" ou "-1"
    cidr_blocks     = optional(list(string), [])
    security_groups = optional(list(string), [])
  }))
  default = []
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}
