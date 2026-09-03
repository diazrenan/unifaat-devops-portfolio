# ==============================
# Grupos IAM
# ==============================

resource "aws_iam_group" "developers" {
  name = "${var.ra}-technova-developers"
}

resource "aws_iam_group" "platform_eng" {
  name = "${var.ra}-technova-platform-eng"
}

# ==============================
# Usuários IAM
# ==============================

resource "aws_iam_user" "juliana_dev" {
  name = "${var.ra}-juliana-dev"

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}

resource "aws_iam_user" "rafael_platform" {
  name = "${var.ra}-rafael-platform"

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}

resource "aws_iam_user" "lucas_intern" {
  name = "${var.ra}-lucas-intern"

  tags = {
    Project    = var.project_name
    ManagedBy  = "Terraform"
    Aluno      = var.aluno
    RA         = var.ra
    Disciplina = "DevOps - UniFAAT 2026-2"
    Aula       = "03"
  }
}

# ==============================
# Membros dos grupos
# ==============================

resource "aws_iam_group_membership" "developers" {
  name  = "${var.ra}-technova-developers-membership"
  group = aws_iam_group.developers.name

  users = [
    aws_iam_user.juliana_dev.name,
    aws_iam_user.rafael_platform.name,
    aws_iam_user.lucas_intern.name
  ]
}

resource "aws_iam_group_membership" "platform_eng" {
  name  = "${var.ra}-technova-platform-eng-membership"
  group = aws_iam_group.platform_eng.name

  users = [
    aws_iam_user.rafael_platform.name
  ]
}