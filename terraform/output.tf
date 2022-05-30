output "endpoint" {
  value = aws_apigatewayv2_stage.socket.invoke_url
}

output "opensearch_domain" {
    value = aws_opensearch_domain.truck.endpoint
}

output "destination_url" {
  value = aws_apigatewayv2_api.socket.api_endpoint
}

output "db_name" {
  value = aws_dynamodb_table.Connection.name
}

output "streamname" {
  value = aws_kinesis_stream.truck_stream.name
}