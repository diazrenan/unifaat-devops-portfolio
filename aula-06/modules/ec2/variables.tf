variable "instance_name" {
  description = "Nome da instância EC2 (usado na tag Name)"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "ID da AMI utilizada para provisionar a instância"
  type        = string
}

variable "subnet_id" {
  description = "ID da subnet onde a instância será criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de IDs dos Security Groups associados à instância"
  type        = list(string)
}

variable "key_name" {
  description = "Nome do Key Pair para acesso SSH"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Script de inicialização da instância (user data) — opcional"
  type        = string
  default     = null
}

variable "environment" {
  description = "Nome do ambiente (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "root_volume_size" {
  description = "Tamanho do volume raiz em GB"
  type        = number
  default     = 20
}
