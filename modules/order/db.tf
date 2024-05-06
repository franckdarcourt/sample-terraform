resource "aws_dynamodb_table" "order_table" {
  name           = "${var.stage_name}-order"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"
  range_key      = "sk"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "vaultId"
    type = "S"
  }

  global_secondary_index {
    name               = "vaultIdIndex"
    hash_key           = "vaultId"
    write_capacity     = 1
    read_capacity      = 1
    projection_type    = "INCLUDE"
    non_key_attributes = ["vaultId"]
  }

  tags = {
    Name        = "dynamodb-table-orders"
    Environment = var.stage_name
  }
}
