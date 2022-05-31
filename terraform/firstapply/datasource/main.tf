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
  profile = "kakao"
  region  = "ap-northeast-2"
}

resource "aws_dynamodb_table" "connectionIds" {
  name = "connectionIds"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "connection_Id"

  attribute {
    name = "connection_Id"
    type = "S"
  }

  tags = {
      Name = "connectionIds"
      Environment = "pay_per_request"
  }
}

