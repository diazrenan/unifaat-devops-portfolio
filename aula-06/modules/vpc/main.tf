locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Separar subnets por tipo usando for_each
  public_subnets  = { for k, v in var.subnets : k => v if v.type == "public" }
  private_subnets = { for k, v in var.subnets : k => v if v.type == "private" }
}

# VPC principal
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.name_prefix}-igw"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Subnets públicas (for_each sobre o mapa filtrado)
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = {
    Name        = "${local.name_prefix}-${each.key}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "public"
  }
}

# Subnets privadas (for_each sobre o mapa filtrado)
resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name        = "${local.name_prefix}-${each.key}"
    Environment = var.environment
    Project     = var.project_name
    Type        = "private"
  }
}

# Route Table pública (com rota para o Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.name_prefix}-public-rt"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Associação de cada subnet pública com a Route Table pública
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}
