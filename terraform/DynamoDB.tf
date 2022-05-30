resource "aws_dynamodb_table" "Connection" {
  name = "Connection"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "connection_Id"

  attribute {
    name = "connection_Id"
    type = "S"
  }

  tags = {
      Name = "Connection"
      Environment = "pay_per_request"
  }
}

