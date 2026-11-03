resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-${var.name}"
  description = "Security Group: ${var.name} | ${var.environment}"
  vpc_id      = var.vpc_id

  # Regras de ingress geradas dinamicamente a partir da lista de objetos
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description     = ingress.value.description
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      cidr_blocks     = ingress.value.cidr_blocks
      security_groups = ingress.value.security_groups
    }
  }

  # Regra de egress padrão — todo tráfego de saída liberado
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-${var.name}"
    Environment = var.environment
    Project     = var.project_name
  }
}
