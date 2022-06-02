terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  backend "s3" {
    bucket = "fin-scenario2"
    key = "fin-scenario2-lambda.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  profile = "kakao"
  region  = "ap-northeast-2"
}

data "terraform_remote_state" "Roles" {
  backend = "s3"

  config = {
    bucket = "fin-scenario2"
    key = "fin-scenario2-roles.tfstate"
    region = "ap-northeast-2"
  }
}

data "archive_file" "send_query_lambda" {
  type = "zip"

  source_dir = "${path.module}/send-query-lambda"
  output_path = "${path.module}/files/send-query-lambda.zip"
  output_file_mode = "0666"
}

data "archive_file" "connect_lambda" {
  type = "zip"

  source_dir = "${path.module}/connect-lambda"
  output_path = "${path.module}/files/connect-lambda.zip"
  output_file_mode = "0666"
}

data "archive_file" "send_truck_data_lambda"{
  type = "zip"

  source_dir = "${path.module}/send-truck-data-lambda"
  output_path = "${path.module}/files/send-truck-data-lambda.zip"
  output_file_mode = "0666"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename = "${path.module}/layer/python_lib.zip"
  layer_name = "python_lib"

  compatible_runtimes = ["python3.7", "python3.8", "python3.9"]
}

resource "aws_lambda_function" "connect_lambda" {
  filename = "${path.module}/files/connect-lambda.zip"
  function_name = "connect-lambda"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "handler.lambda_handler"

  source_code_hash = data.archive_file.connect_lambda.output_base64sha256
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  timeout = 60

  runtime = "python3.8"
}

resource "aws_lambda_function" "send_truck_data_lambda" {
  filename = "${path.module}/files/send-truck-data-lambda.zip"
  function_name = "send-truck-data-lambda"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "handler.lambda_handler"

  source_code_hash = data.archive_file.send_truck_data_lambda.output_base64sha256
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  timeout = 60

  runtime = "python3.8"

  environment {
    variables = {
        streamname = aws_kinesis_stream.truck_stream.name
        PartitionKey = var.PartitionKey
    }
  }
}

resource "aws_lambda_function" "send_query_lambda" {
  filename = "${path.module}/files/send-query-lambda.zip"
  function_name = "send-query-lambda"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "handler.lambda_handler"

  source_code_hash = data.archive_file.send_query_lambda.output_base64sha256
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  timeout = 30

  runtime = "python3.8"

  environment {
    variables = {
        OPENSEARCH_DOMAIN = aws_opensearch_domain.truck.endpoint
        OPENSEARCH_INDEX = var.opensearch_index
        DESTINATION_URL = aws_apigatewayv2_stage.socket.invoke_url
        DB_TABLE_NAME = aws_dynamodb_table.Connection.name
    }
  }
}

# AWS_SQS for Dead Letter Queue of Send query lambda
resource "aws_sqs_queue" "dlq" {
  name = "dlq"
  delay_seconds = 0
  max_message_size = 2048
  message_retention_seconds = 86400
  receive_wait_time_seconds = 0

    tags = {
      environment = "production"
  }
}

resource "aws_lambda_event_source_mapping" "dlq" {
  event_source_arn = aws_sqs_queue.dlq.arn
  function_name = aws_lambda_function.send_query_lambda.function_name
}

resource "aws_lambda_function_event_invoke_config" "send_query_lambda" {
  function_name = aws_lambda_function.send_query_lambda.function_name
  maximum_event_age_in_seconds = 100
  maximum_retry_attempts = 1

  destination_config {
    on_failure {
        destination = aws_sqs_queue.dlq.arn
    }
  }
}

