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
    key = "fin-scenario2-roles.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "kakao"
  region  = "ap-northeast-2"
}

data "terraform_remote_state" "lambdaSrc" {
  backend = "s3"

  config = {
    bucket = "fin-scenario2"
    key = "fin-scenario2-lambda.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "dbSrc" {
  backend = "s3"

  config = {
    bucket = "fin-scenario2"
    key = "fin-scenario2-db.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "esSrc" {
  backend = "s3"

  config = {
    bucket = "fin-scenario2"
    key = "fin-scenario2-es.tfstate"
    region = "ap-northeast-2"
  }
}

resource "aws_iam_role" "firehoseRole" {
  name = "firehose_test_role"

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

resource "aws_iam_role" "lambdaIam" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambdaIam" {
  role       = aws_iam_role.lambdaIam.name
  policy_arn = aws_iam_policy.lambdaIam.arn
}

resource "aws_iam_policy" "lambdaIam" {
    policy = data.aws_iam_policy_document.lambdaIam.json
}

data "aws_iam_policy_document" "lambdaIam" {
  statement {
    sid       = "AllowSQSPermissions"
    effect    = "Allow"
    resources = ["arn:aws:sqs:*"]

    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]
  }

  statement {
    sid       = "AllowDynamoPermissions"
    effect    = "Allow"
    resources = ["${data.terraform_remote_state.dbSrc.outputs.dbArn}"]

    actions = [
        "dynamodb:*",
    ]
  }

  statement {
    sid       = "AllowInvokingLambdas"
    effect    = "Allow"
    resources = ["arn:aws:lambda:ap-northeast-2:*:function:*"]
    actions   = ["lambda:InvokeFunction"]
  }

  statement {
    sid       = "AllowKinesisLambdas"
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kinesis:*"]    
  }

  statement {
    sid       = "AllowEsPermission"
    effect    = "Allow"
    resources = [
      "*",
    ]
    actions   = [
      "es:ESHttpGet",
      "es:ESHttpPut",
      "es:ESHttpPost",
      "es:ESHttpHead",
      "es:ESHttpDelete",
      "es:Describe*",
      "es:List*"
      ]
  }

  statement {
    sid       = "AllowAPIGatewayInvokePermission"
    effect    = "Allow"
    resources = [
      "arn:aws:execute-api:*:*:*",
    ]
    actions   = [
        "execute-api:Invoke",
        "execute-api:ManageConnections"
      ]
  }

  statement {
    sid       = "AllowCreatingLogGroups"
    effect    = "Allow"
    resources = ["arn:aws:logs:ap-northeast-2:*:*"]
    actions   = ["logs:CreateLogGroup"]
  }
  statement {
    sid       = "AllowWritingLogs"
    effect    = "Allow"
    resources = ["arn:aws:logs:ap-northeast-2:*:log-group:/aws/lambda/*:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "deliverFirehoseToEsPolicy" {
  name = "firehose-es-delivery-policy"
  path = "/"
  description = "Kinesis Firehose ES delivery policy"

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
  name        = "firehose-delivery-policy"
  path        = "/"
  description = "Kinesis Firehose delivery policy"

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
  policy_arn = aws_iam_policy.deliverFirehoseToEsPolicy.arn
}

resource "aws_iam_role_policy_attachment" "attach_kinesis_firehose" {
  role = aws_iam_role.firehose_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonKinesisFirehoseFullAccess"
}

resource "aws_lambda_permission" "send_truck_data_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambdaSrc.outputs.truckDataFunctionName
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.send_truck_data_api.execution_arn}/*/*"
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
