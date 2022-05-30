resource "aws_kinesis_stream" "truck_stream" {
  name = "terraform-kinesis-truck"
  retention_period = 24

  shard_level_metrics = [
      "IncomingBytes",
      "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
      Environment = "truck_stream"
  }
}