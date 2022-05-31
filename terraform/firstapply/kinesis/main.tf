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
    key = "fin-scenario2-kinesis.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "kakao"
  region  = "ap-northeast-2"
}

resource "aws_kinesis_stream" "truck_stream" {
  name = "terraform-kinesis-truck"
  retention_period = 24

  shard_level_metrics = [
      "IncomingBytes",
      "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
      Environment = "truck_stream"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "truck_firehose" {
  name = "terraform-kinesis-firehose-truck-firehose"
  destination = "elasticsearch"

  s3_configuration {
    role_arn = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
    buffer_size = 10
    buffer_interval = 400
    compression_format = "GZIP"
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.truck_stream.arn
    role_arn = aws_iam_role.firehose_role.arn
  }

  elasticsearch_configuration {
    domain_arn = aws_opensearch_domain.truck.arn
    role_arn = aws_iam_role.firehose_role.arn
    index_name = "opensearch-index"
    retry_duration = 60
    index_rotation_period = "NoRotation"
    buffering_interval = 60
    buffering_size = 5

    cloudwatch_logging_options {
      enabled = true
      log_group_name = "firehose-log"
      log_stream_name = "stream-log"
    }
  }
}