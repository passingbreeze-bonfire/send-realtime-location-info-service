output "ESbucketName" {
    value = aws_s3_bucket.bucket.bucket
}

output "ESbucketArn" {
    value = aws_s3_bucket.bucket.arn
}

output "ESdomainArn" {
    value = aws_opensearch_domain.truckLogs.arn
}

output "ESdomainURL" {
    value = aws_opensearch_domain.truckLogs.endpoint
}

output "ESdomainName" {
    value = aws_opensearch_domain.truckLogs.domain_name
}