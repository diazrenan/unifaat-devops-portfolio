variable "vpc_cidr" {
  description = "CIDR block da VPC"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
}

variable "subnets" {
  description = "Mapa de subnets com cidr, az e type (public | private)"
  type = map(object({
    cidr = string
    az   = string
    type = string # "public" ou "private"
  }))

  validation {
    condition = alltrue([
      for k, v in var.subnets : contains(["public", "private"], v.type)
    ])
    error_message = "O campo 'type' de cada subnet deve ser 'public' ou 'private'."
  }
}
