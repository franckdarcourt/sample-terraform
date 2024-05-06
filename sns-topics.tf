resource "aws_sns_topic" "order_created" {
  name = "${var.stage_name}-order-created"
}

resource "aws_sns_topic" "order_deleted" {
  name = "${var.stage_name}-order-deleted"
}
