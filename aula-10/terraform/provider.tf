terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # -----------------------------------------------------------------------
  # Backend S3 — estado remoto compartilhado entre plan e apply
  # O bucket deve existir antes do primeiro `terraform init`
  # Crie manualmente via AWS Console ou AWS CLI:
  #   aws s3 mb s3://technova-tfstate-<sua-conta> --region us-east-1
  #   aws s3api put-bucket-versioning \
  #     --bucket technova-tfstate-<sua-conta> \
  #     --versioning-configuration Status=Enabled
  # -----------------------------------------------------------------------
  backend "s3" {
    bucket         = "technova-tfstate-441907008326"
    key            = "aula-10/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "technova-aula-10"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
