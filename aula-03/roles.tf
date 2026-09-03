# ==========================================
# Trust Policy - EC2 pode assumir a Role
# ==========================================

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}


# ==========================================
# Service Role do EC2
# ==========================================

resource "aws_iam_role" "ec2_role" {
  name = "${var.ra}-technova-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}


# ==========================================
# Permissões S3 para o EC2
# ==========================================

data "aws_iam_policy_document" "ec2_s3_access" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::technova-app-data-*",
      "arn:aws:s3:::technova-app-data-*/*"
    ]
  }
}


resource "aws_iam_role_policy" "ec2_s3_access" {
  name = "${var.ra}-technova-ec2-s3-access"

  role = aws_iam_role.ec2_role.id

  policy = data.aws_iam_policy_document.ec2_s3_access.json
}


# ==========================================
# Instance Profile
# ==========================================

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.ra}-technova-ec2-profile"

  role = aws_iam_role.ec2_role.name

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}