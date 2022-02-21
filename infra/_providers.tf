terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.63"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Owner       = var.owner
      Environment = var.environment
    }
  }
}
