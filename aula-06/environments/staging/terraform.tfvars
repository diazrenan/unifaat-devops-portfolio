aws_region   = "us-east-1"
environment  = "staging"
project_name = "unifaat-devops"

vpc_cidr = "10.1.0.0/16"

subnets = {
  "public-subnet-1" = {
    cidr = "10.1.1.0/24"
    az   = "us-east-1a"
    type = "public"
  }
  "public-subnet-2" = {
    cidr = "10.1.2.0/24"
    az   = "us-east-1b"
    type = "public"
  }
  "private-subnet-1" = {
    cidr = "10.1.10.0/24"
    az   = "us-east-1a"
    type = "private"
  }
  "private-subnet-2" = {
    cidr = "10.1.11.0/24"
    az   = "us-east-1b"
    type = "private"
  }
}

# EC2
instance_type = "t2.micro"
ami_id        = "ami-0c02fb55956c7d316" # Amazon Linux 2 - us-east-1

# RDS PostgreSQL
db_instance_class = "db.t3.micro"
db_name           = "stagingdb"
db_username       = "postgres"
# db_password deve ser definido via variável de ambiente:
# $env:TF_VAR_db_password = "sua-senha-aqui"
