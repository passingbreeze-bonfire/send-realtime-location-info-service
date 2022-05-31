output "dbId" {
  value = aws_dynamodb_table.connectionIds.id
}

output "dbArn" {
   value = aws_dynamodb_table.connectionIds.arn 
}

output "dbName" {
   value = aws_dynamodb_table.connectionIds.name
}