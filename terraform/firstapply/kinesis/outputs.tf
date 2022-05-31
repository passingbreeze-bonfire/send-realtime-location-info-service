output "kinesisId" {
  value = aws_kinesis_stream.truck_stream.id
}

output "kinesisArn" {
    value = aws_kinesis_stream.truck_stream.arn
}

output "kinesisName" {
    value = aws_kinesis_stream.truck_stream.name
}