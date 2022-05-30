variable "opensearch_index" {
  type = string
  default = "input your index name"
}

variable "region" {
  type = string
  default = "REGION"
}

variable "account_id" {
  type = string
  default = "${secrets.ACCOUNT_ID}"
}

variable "user_name" {
  type = string
  default = "${secrets.USER_NAME}"
}

variable "user_password" {
  type = string
  default = "${secrets.USER_PASSWORD}"
}

variable "PartitionKey" {
  type = string
  default = "${secrets.PARTITIONKEY}"
}
