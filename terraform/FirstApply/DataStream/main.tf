terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-teama"  # 미리 만들어둔 bucket, 테라폼으로 만들면 안됩니다.
    key = "fin-scenario2-kinesis.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "gmail"
}

resource "aws_opensearch_domain" "truck" {
  domain_name = "terraform-truck-logs"
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
      master_user_name = var.master_user_name
      master_user_password = var.master_user_password
    }
  }

  cluster_config {
    instance_type = "t3.small.search"
  }
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
    index_name = "terraform-truck-drivers-log"
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
      "Resource": "${aws_opensearch_domain.truck.arn}/*"
    }
  ]
}
POLICIES
}

resource "aws_iam_role" "firehose_role" {
  name = "terraform_firehose_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}


resource "aws_iam_policy" "firehose_es_delivery_policy" {
  name = "terraform-firehose-es-delivery-policy"
  path = "/"
  description = "Kinesis Firehose ES delivery policy from terraform"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "es:DescribeElasticsearchDomain",
                "es:DescribeElasticsearchDomains",
                "es:DescribeElasticsearchDomainConfig",
                "es:ESHttpPost",
                "es:ESHttpPut"
            ],
            "Resource": [
                "${aws_opensearch_domain.truck.arn}/*",
                "${aws_opensearch_domain.truck.arn}"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "es:ESHttpGet"
            ],
            "Resource": [
                "${aws_opensearch_domain.truck.arn}/_all/_settings",
                "${aws_opensearch_domain.truck.arn}/_cluster/stats",
                "${aws_opensearch_domain.truck.arn}/cxcloud*/_mapping/logs",
                "${aws_opensearch_domain.truck.arn}/_nodes",
                "${aws_opensearch_domain.truck.arn}/_nodes/stats",
                "${aws_opensearch_domain.truck.arn}/_nodes/*/stats",
                "${aws_opensearch_domain.truck.arn}/_stats",
                "${aws_opensearch_domain.truck.arn}/cxcloud*/_stats"
            ]
        }
    ]
  })
}

resource "aws_iam_policy" "firehose_delivery_policy" {
  name        = "terraform-firehose-delivery-policy"
  path        = "/"
  description = "Kinesis Firehose delivery policy from terraform"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "${aws_s3_bucket.bucket.arn}",
                "${aws_s3_bucket.bucket.arn}/*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/kinesisfirehose/${aws_kinesis_stream.truck_stream.name}:log-stream:*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords"
            ],
            "Resource": "*"
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_delivery_policy" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_delivery_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_es_delivery_policy" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_es_delivery_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_kinesis_firehose" {
  role = aws_iam_role.firehose_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFirehoseFullAccess"
}
