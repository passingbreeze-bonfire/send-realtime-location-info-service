output "connectInvokeArn" {
    value =  aws_lambda_function.connect_lambda.invoke_arn
}

output "connectFunctionName" {
    value =  aws_lambda_function.connect_lambda.function_name
}

output "sendTruckDataInvokeArn" {
    value =  aws_lambda_function.send_truck_data_lambda.invoke_arn
}

output "sendTruckDataFunctionName" {
    value =  aws_lambda_function.send_truck_data_lambda.function_name
}

output "socket_endpoint" {
  value = aws_apigatewayv2_stage.socket.invoke_url
}

output "destination_url" {
  value = aws_apigatewayv2_api.socket.api_endpoint
}
