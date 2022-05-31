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
    key = "fin-scenario2-apigw.tfstate"
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
  integration_uri = data.terraform_remote_state.lambdaSrc.outputs.connectInvokeArn
  integration_type = "AWS_PROXY"
  integration_method = "POST"  
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
  uri = data.terraform_remote_state.lambdaSrc.outputs.sendQueryInvokeArn
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
}
