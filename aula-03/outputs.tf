# ==========================================
# Outputs - Usuários
# ==========================================

output "iam_users" {
  description = "Usuários IAM criados"
  value = [
    aws_iam_user.juliana_dev.name,
    aws_iam_user.rafael_platform.name,
    aws_iam_user.lucas_intern.name
  ]
}


# ==========================================
# Outputs - Grupos
# ==========================================

output "iam_groups" {
  description = "Grupos IAM criados"
  value = [
    aws_iam_group.developers.name,
    aws_iam_group.platform_eng.name
  ]
}


# ==========================================
# Outputs - Policies
# ==========================================

output "s3_read_policy_arn" {
  description = "ARN da política de leitura S3"
  value       = aws_iam_policy.s3_read.arn
}

output "platform_full_policy_arn" {
  description = "ARN da política EC2 + S3"
  value       = aws_iam_policy.platform_full.arn
}

output "deny_destructive_policy_arn" {
  description = "ARN da política de negação de ações destrutivas"
  value       = aws_iam_policy.deny_destructive.arn
}


# ==========================================
# Output - Service Role
# ==========================================

output "ec2_role_arn" {
  description = "ARN da Service Role utilizada pelo EC2"
  value       = aws_iam_role.ec2_role.arn
}


# ==========================================
# Output - Instance Profile
# ==========================================

output "ec2_instance_profile_name" {
  description = "Nome do Instance Profile do EC2"
  value       = aws_iam_instance_profile.ec2_profile.name
}