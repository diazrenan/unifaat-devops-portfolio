locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# DB Subnet Group com subnets privadas
resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Subnet group para o RDS do ambiente ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "${local.name_prefix}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Instância RDS PostgreSQL
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-rds"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  # Configurações sensatas para desenvolvimento
  multi_az                = false
  publicly_accessible     = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true

  tags = {
    Name        = "${local.name_prefix}-rds"
    Environment = var.environment
    Project     = var.project_name
  }
}
