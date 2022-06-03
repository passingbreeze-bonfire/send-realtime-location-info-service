terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-teama"
    key = "fin-scenario2-db.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "gmail"
}

resource "aws_dynamodb_table" "connectionTable" {
  name = "connectionTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "connection_Id"

  attribute {
    name = "connection_Id"
    type = "S"
  }

  tags = {
      Name = "Connection"
      Environment = "pay_per_request"
  }
}

