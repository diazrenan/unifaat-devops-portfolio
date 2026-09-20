# Tabela DynamoDB para locking do Terraform state
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "technova-terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project = "TechNova"
    Purpose = "Terraform Remote State"
  }
}
