output "streamName" {
  value = aws_kinesis_stream.truck_stream.name
}

output "opensearchEndpoint" {
    value = aws_opensearch_domain.truck.endpoint
}
