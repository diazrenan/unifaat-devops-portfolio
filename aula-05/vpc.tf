# Data source para AZs disponíveis na região
data "aws_availability_zones" "available" {
  state = "available"
}

# ─────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# Subnet pública
# ─────────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-subnet-public"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# Subnets privadas (RDS — AZs diferentes)
# ─────────────────────────────────────────────
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name    = "${var.project_name}-subnet-private-a"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name    = "${var.project_name}-subnet-private-b"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# Internet Gateway
# ─────────────────────────────────────────────
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# Route table pública
# ─────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-rtb-public"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# Associação da route table pública com a subnet pública
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
