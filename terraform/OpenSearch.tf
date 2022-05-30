resource "aws_opensearch_domain" "truck" {
  domain_name = "truck"
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

resource "aws_opensearch_domain_policy" "main" {
  domain_name = aws_opensearch_domain.truck.domain_name

  access_policies = <<POLICIES
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "es:*",
      "Condition": {
          "IpAddress": {"aws:SourceIp": "218.235.89.144/32"}
      },
      "Resource": "${aws_opensearch_domain.truck.arn}/*"
    }
  ]
}
POLICIES
}

resource "aws_s3_bucket" "bucket" {
  bucket = "tf-truck-bucket"
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl = "private"
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