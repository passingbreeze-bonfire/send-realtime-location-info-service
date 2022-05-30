resource "aws_iam_role" "firehose_role" {
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

resource "aws_iam_role" "iam_for_lambda" {
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

resource "aws_iam_role_policy_attachment" "iam_for_lambda" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.iam_for_lambda.arn
}

resource "aws_iam_policy" "iam_for_lambda" {
    policy = data.aws_iam_policy_document.iam_for_lambda.json
}

data "aws_iam_policy_document" "iam_for_lambda" {
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
    resources = ["${aws_dynamodb_table.Connection.arn}"]

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

resource "aws_iam_policy" "firehose_es_delivery_policy" {
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
                "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/kinesisfirehose/terraform-kinesis-truck:log-stream:*"
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
            "Resource": "arn:aws:kinesis:${var.region}:${var.account_id}:stream/terraform-kinesis-truck"
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
