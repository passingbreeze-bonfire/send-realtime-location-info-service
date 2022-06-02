terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "fin-scenario2"
    key = "fin-scenario2-db.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  access_key = var.access_key
  secret_key = var.secret_key
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

