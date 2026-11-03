# Chave KMS para encriptação server-side do bucket S3

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state S3 bucket encryption"
  deletion_window_in_days = 10

  tags = {
    Project = "TechNova"
    Purpose = "Terraform Remote State"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/technova-terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# Bucket S3 para armazenar o terraform.tfstate
data "aws_s3_bucket" "terraform_state" {
  bucket = "technova-terraform-state-9a2fd334"
}

# Versionamento habilitado
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encriptação server-side com KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
    bucket_key_enabled = true
  }
}

# Block Public Access — todas as 4 configurações habilitadas
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = data.aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
