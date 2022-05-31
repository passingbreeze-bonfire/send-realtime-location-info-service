output "connectFunctionName" {
    value = aws_lambda_function.connect_lambda.function_name
}

output "connectArn" {
    value = aws_lambda_function.connect_lambda.arn
}

output "connectInvokeArn" {
    value = aws_lambda_function.connect_lambda.invoke_arn
}

output "sendQueryFunctionName" {
    value = aws_lambda_function.send_query_lambda.function_name
}

output "sendQueryArn" {
    value = aws_lambda_function.send_query_lambda.arn
}

output "sendQueryInvokeArn" {
    value = aws_lambda_function.send_query_lambda.invoke_arn
}

output "truckDataFunctionName" {
    value = aws_lambda_function.send_truck_data_lambda.function_name
}

output "truckDataArn" {
    value = aws_lambda_function.send_truck_data_lambda.arn
}

output "truckDataInvokeArn" {
    value = aws_lambda_function.send_truck_data_lambda.invoke_arn
}
