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
    key = "fin-scenario2-es.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "kakao"
  region  = "ap-northeast-2"
}

resource "aws_opensearch_domain" "truckLogs" {
  domain_name = "truckLogs"
  engine_version = "OpenSearch_1.2"

  node_to_node_encryption {
    enabled = true
  }

  encrypt_at_rest {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https = true
    tls_security_policy = "Policy-Min-TLS-1-0-2019-07"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp2"
  }

  advanced_security_options {
    enabled = true
    internal_user_database_enabled = true

    master_user_options {
      master_user_name = var.user_name
      master_user_password = var.user_password
    }
  }

  cluster_config {
    instance_type = "t3.small.search"
  }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-truck-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl = "private"
}

