output "tableArn" {
    value = aws_dynamodb_table.connectionTable.arn
}

output "tableName" {
    value = aws_dynamodb_table.connectionTable.name
}