# ─────────────────────────────────────────────
# DB Subnet Group (subnets privadas em AZs distintas)
# ─────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# Security Group do RDS
# ─────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-sg-rds"
  description = "Permite acesso PostgreSQL somente de dentro da VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "PostgreSQL da VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-rds"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# RDS PostgreSQL
# ─────────────────────────────────────────────
resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-postgres"
  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false
  publicly_accessible = false
  storage_encrypted   = true
  skip_final_snapshot = true

  tags = {
    Name    = "${var.project_name}-postgres"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}
