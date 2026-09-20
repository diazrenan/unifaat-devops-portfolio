# ─────────────────────────────────────────────
# Data source — AMI Amazon Linux 2023 (x86_64)
# ─────────────────────────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─────────────────────────────────────────────
# Security Group da EC2
# ─────────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-sg-ec2"
  description = "Permite SSH e acesso a API na EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "API"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg-ec2"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}

# ─────────────────────────────────────────────
# Instância EC2
# ─────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  key_name                    = "technova-key"
  vpc_security_group_ids      = [aws_security_group.ec2.id]

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name    = "${var.project_name}-app"
    Project = "TechNova"
    Aula    = "Aula 05"
  }
}
