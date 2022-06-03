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
    key = "fin-scenario2-lambda.tfstate"
    region = "ap-northeast-2"
  }
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "gmail"
}

data "terraform_remote_state" "dynamoTable" {
    backend = "s3"

  config = {
    bucket = "terraform-state-teama"
    key = "fin-scenario2-db.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "kinesisStream" {
    backend = "s3"

  config = {
    bucket = "terraform-state-teama"
    key = "fin-scenario2-kinesis.tfstate"
    region = "ap-northeast-2"
  }
}

######### lambda file ###########

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

####################################################################

resource "aws_lambda_function" "send_query_lambda" {
  filename = "${path.module}/files/send-query-lambda.zip"
  function_name = "send-query-lambda-from-terraform"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "handler.lambda_handler"

  source_code_hash = data.archive_file.send_query_lambda.output_base64sha256
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  timeout = 30

  runtime = "python3.8"

  environment {
    variables = {
        OPENSEARCH_DOMAIN = data.terraform_remote_state.kinesisStream.outputs.opensearchEndpoint
        OPENSEARCH_INDEX = "terraform-truck-drivers-log"
        DESTINATION_URL = aws_apigatewayv2_stage.socket.invoke_url
        DB_TABLE_NAME = data.terraform_remote_state.dynamoTable.outputs.tableName
    }
  }
}

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

# # CloudWatch
# resource "aws_cloudwatch_log_group" "send_query_lambda" {
#   name = "/aws/lambda/${aws_lambda_function.send_query_lambda.function_name}"

#   retention_in_days = 30
# }

# EventBridge
resource "aws_cloudwatch_event_rule" "lambda_event_rule" {
  name = "lambda-event-rule-terraform"
  description = "trigger lambda every 1 min"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda_event_target" {
  arn = aws_lambda_function.send_query_lambda.arn
  rule = aws_cloudwatch_event_rule.lambda_event_rule.name
}

resource "aws_lambda_permission" "allow_event_call" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_query_lambda.function_name
  principal = "events.amazonaws.com"
  source_arn = aws_cloudwatch_event_rule.lambda_event_rule.arn
}

##################################################################################

resource "aws_lambda_function" "connect_lambda" {
  filename = "${path.module}/files/connect-lambda.zip"
  function_name = "connect-lambda-terraform"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "handler.lambda_handler"

  source_code_hash = data.archive_file.connect_lambda.output_base64sha256
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  timeout = 60

  runtime = "python3.8"

  environment {
    variables = {
        DB_TABLE_NAME = data.terraform_remote_state.dynamoTable.outputs.tableName
    }
  }
}

# CloudWatch
resource "aws_cloudwatch_log_group" "connect_lambda" {
  name = "/aws/lambda/${aws_lambda_function.connect_lambda.function_name}"

  retention_in_days = 30
}


# API Gateway
resource "aws_apigatewayv2_api" "socket" {
  name                       = "websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_stage" "socket" {
  api_id = aws_apigatewayv2_api.socket.id
  name = "dev"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit = 100
    throttling_burst_limit = 50
  }
}

resource "aws_apigatewayv2_deployment" "socket" {
  api_id = aws_apigatewayv2_api.socket.id
  
  triggers = {
    redeployment = sha1(join(",", tolist([
      jsonencode(aws_apigatewayv2_integration.socket),
      jsonencode(aws_apigatewayv2_route.connect),
    ])))
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.socket.id
  route_key = "$connect"
  operation_name = "connect"
  target = "integrations/${aws_apigatewayv2_integration.socket.id}"
}

resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.socket.id
  route_key = "$disconnect"
  operation_name = "disconnect"
  target = "integrations/${aws_apigatewayv2_integration.socket.id}"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.socket.id
  route_key = "$default"
  operation_name = "default"
  target = "integrations/${aws_apigatewayv2_integration.socket.id}"
}

resource "aws_apigatewayv2_integration" "socket" {
  api_id           = aws_apigatewayv2_api.socket.id
  integration_uri = aws_lambda_function.connect_lambda.invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"  
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id = "AllowExecutionFromApiGateway"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.connect_lambda.function_name
  principal = "apigateway.amazonaws.com"

  // source_arn = "${aws_apigatewayv2_api.socket.execution_arn}/*/*/*"
  source_arn = "${aws_apigatewayv2_api.socket.execution_arn}/*/*"
}

#############################################################################################3

resource "aws_lambda_function" "send_truck_data_lambda" {
  filename = "${path.module}/files/send-truck-data-lambda.zip"
  function_name = "send-truck-data-lambda-terraform"
  role = aws_iam_role.iam_for_lambda.arn
  handler = "handler.lambda_handler"

  source_code_hash = data.archive_file.send_truck_data_lambda.output_base64sha256
  layers = [aws_lambda_layer_version.lambda_layer.arn]
  timeout = 60

  runtime = "python3.8"

  environment {
    variables = {
        streamname = data.terraform_remote_state.kinesisStream.outputs.streamName
        PartitionKey = var.PartitionKey
    }
  }
}

# CloudWatch
resource "aws_cloudwatch_log_group" "send_truck_data_lambda" {
  name = "/aws/lambda/${aws_lambda_function.send_truck_data_lambda.function_name}"

  retention_in_days = 30
}

resource "aws_api_gateway_rest_api" "send_truck_data_api" {
  name = "send_truck_data_api"
}

resource "aws_api_gateway_resource" "send_truck_data_api" {
  path_part = "send"
  parent_id = aws_api_gateway_rest_api.send_truck_data_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id
}

resource "aws_api_gateway_method" "send_truck_data_api" {
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id
  resource_id = aws_api_gateway_resource.send_truck_data_api.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "send_truck_data_api" {
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id
  resource_id = aws_api_gateway_resource.send_truck_data_api.id
  http_method = aws_api_gateway_method.send_truck_data_api.http_method
  integration_http_method = "POST"
  type = "AWS"
  uri = aws_lambda_function.send_truck_data_lambda.invoke_arn
}

resource "aws_lambda_permission" "send_truck_data_api" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_truck_data_lambda.function_name
  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.send_truck_data_api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "send_truck_data_api" {
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.send_truck_data_api.id,
      aws_api_gateway_method.send_truck_data_api.id,
      aws_api_gateway_integration.send_truck_data_api.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "send_truck_data_api" {
  deployment_id = aws_api_gateway_deployment.send_truck_data_api.id
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id
  stage_name = "dev"
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id
  resource_id = aws_api_gateway_resource.send_truck_data_api.id
  http_method = aws_api_gateway_method.send_truck_data_api.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "send_truck_data_api" {
  rest_api_id = aws_api_gateway_rest_api.send_truck_data_api.id
  resource_id = aws_api_gateway_resource.send_truck_data_api.id
  http_method = aws_api_gateway_method.send_truck_data_api.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  
  depends_on = [
    aws_api_gateway_integration.send_truck_data_api
  ]
}


#################################################################33
resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda-from-terraform"

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
    resources = ["${data.terraform_remote_state.dynamoTable.outputs.tableArn}"]

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