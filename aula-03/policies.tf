# ==========================================
# Política 1 - S3 Read para Developers
# ==========================================

data "aws_iam_policy_document" "s3_read" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::technova-*",
      "arn:aws:s3:::technova-*/*"
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${var.ra}-technova-s3-read"
  description = "Permite leitura dos buckets S3 da TechNova"

  policy = data.aws_iam_policy_document.s3_read.json

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}

resource "aws_iam_group_policy_attachment" "developers_s3_read" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.s3_read.arn
}


# ==========================================
# Política 2 - EC2 + S3 para Platform
# ==========================================

data "aws_iam_policy_document" "platform_full" {

  # Permissões de consulta da EC2
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]

    resources = ["*"]
  }

  # Start/Stop somente em instâncias da TechNova
  statement {
    effect = "Allow"

    actions = [
      "ec2:StartInstances",
      "ec2:StopInstances"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  # Acesso de leitura e escrita no S3
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::technova-*",
      "arn:aws:s3:::technova-*/*"
    ]
  }
}

resource "aws_iam_policy" "platform_full" {
  name        = "${var.ra}-technova-ec2-s3-full"
  description = "Permite gerenciamento de EC2 e leitura e escrita no S3"

  policy = data.aws_iam_policy_document.platform_full.json

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}

resource "aws_iam_group_policy_attachment" "platform_full" {
  group      = aws_iam_group.platform_eng.name
  policy_arn = aws_iam_policy.platform_full.arn
}


# ==========================================
# Política 3 - Deny Destructive
# ==========================================

data "aws_iam_policy_document" "deny_destructive" {
  statement {
    effect = "Deny"

    actions = [
      "s3:Delete*",
      "ec2:Terminate*"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "deny_destructive" {
  name        = "${var.ra}-technova-deny-destructive"
  description = "Impede ações destrutivas para usuários Developers"

  policy = data.aws_iam_policy_document.deny_destructive.json

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}

resource "aws_iam_group_policy_attachment" "developers_deny_destructive" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.deny_destructive.arn
}