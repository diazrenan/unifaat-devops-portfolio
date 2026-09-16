resource "aws_key_pair" "technova" {
  key_name   = "technova-key"
  public_key = file("C:/Users/Renan/.ssh/technova-key.pub")

  tags = {
    Name        = "technova-key"
    Project     = "TechNova"
    Environment = "development"
    ManagedBy   = "Terraform"
    Owner       = var.owner
  }
}