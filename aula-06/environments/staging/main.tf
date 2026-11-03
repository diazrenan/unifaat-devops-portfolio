# =============================================================================
# Ambiente: staging
# Região:   us-east-1 | CIDR: 10.1.0.0/16
# Instâncias maiores e configurações próximas de produção para homologação
# =============================================================================

# -----------------------------------------------------------------------------
# 1. VPC — rede base de toda a infraestrutura
# -----------------------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  subnets      = var.subnets
}

# -----------------------------------------------------------------------------
# 2. Security Groups
#    vpc_id vem do output do módulo VPC  ← Composição
# -----------------------------------------------------------------------------

# SG da API/servidor de aplicação
module "api_sg" {
  source = "../../modules/security-group"

  name         = "api-sg"
  vpc_id       = module.vpc.vpc_id  # ← Composição: output do VPC
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      description     = "HTTP publico"
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "HTTPS publico"
      from_port       = 443
      to_port         = 443
      protocol        = "tcp"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
    },
    {
      description     = "SSH restrito ao time de infraestrutura"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      cidr_blocks     = ["10.0.0.0/8"] # acesso apenas via VPN/rede corporativa
      security_groups = []
    }
  ]
}

# SG do banco de dados — acesso exclusivo a partir do SG da API
module "rds_sg" {
  source = "../../modules/security-group"

  name         = "rds-sg"
  vpc_id       = module.vpc.vpc_id  # ← Composição: output do VPC
  environment  = var.environment
  project_name = var.project_name

  ingress_rules = [
    {
      description     = "PostgreSQL somente da camada de API"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      cidr_blocks     = []
      security_groups = [module.api_sg.sg_id]  # ← Composição: output do api_sg
    }
  ]
}

# -----------------------------------------------------------------------------
# 3. EC2 — servidor da API na subnet pública
#    subnet_id e security_group_ids vêm dos módulos anteriores  ← Composição
# -----------------------------------------------------------------------------
module "api_server" {
  source = "../../modules/ec2"

  instance_name      = "${var.project_name}-${var.environment}-api"
  environment        = var.environment
  project_name       = var.project_name
  ami_id             = var.ami_id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.public_subnet_ids["public-subnet-1"]  # ← Composição: output do VPC
  security_group_ids = [module.api_sg.sg_id]                            # ← Composição: output do api_sg
  key_name           = var.key_name
}

# -----------------------------------------------------------------------------
# 4. RDS — banco de dados nas subnets privadas
#    subnet_ids e security_group_ids vêm dos módulos anteriores  ← Composição
# -----------------------------------------------------------------------------
module "database" {
  source = "../../modules/rds"

  project_name       = var.project_name
  environment        = var.environment
  instance_class     = var.db_instance_class
  db_name            = var.db_name
  db_username        = var.db_username
  db_password        = var.db_password
  subnet_ids         = values(module.vpc.private_subnet_ids)  # ← Composição: output do VPC
  security_group_ids = [module.rds_sg.sg_id]                  # ← Composição: output do rds_sg
}
