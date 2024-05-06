# ---------------------------------------------------------------------------------------------------------------------
# ORDER SERVICE LAMBDA
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_lambda_function" "order_service" {
  s3_bucket     = "${var.release_packages_bucket_name}"
  s3_key        = "order-service.zip"
  function_name = "${var.stage_name}-order-service"
  handler       = "bootstrap"
  runtime       = "provided.al2"
  architectures = ["arm64"]
  role          = aws_iam_role.order_service_lambda_role.arn
  
  environment {
    variables = {
      API_BASE_URL = "${aws_api_gateway_stage.order_api.invoke_url}/api/v1/orders/"
      order_deleted_SOURCE_ARN = aws_sqs_queue.order_service_order_deleted.arn
      CUSTODIANSHIP_APPROVAL_URL        = "${aws_api_gateway_stage.order_setup_api.invoke_url}/api/v1/orders/{orderId}/custodians/{id}"
      CUSTODIANSHIP_APPROVED_SOURCE_ARN = aws_sqs_queue.custodianship_approved.arn
      CUSTODIANSHIP_DENIED_SOURCE_ARN   = aws_sqs_queue.custodianship_denied.arn
    }
  }
}

data "aws_iam_policy_document" "order_service_lambda_role_iam_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "order_service_lambda_role" {
  name               = "${var.stage_name}-order-service-role"
  assume_role_policy = data.aws_iam_policy_document.order_service_lambda_role_iam_policy.json
  inline_policy {
    name = "${var.stage_name}-api-gateway-access-order-service-role"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["execute-api:Invoke"]
          Effect   = "Allow"
          Resource = "${aws_api_gateway_stage.order_setup_api.execution_arn}/*/*"
        },
      ]
    })
  }
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_role_policy" {
  role       = aws_iam_role.order_service_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}


# ---------------------------------------------------------------------------------------------------------------------
# ORDER DELETED QUEUE
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_sqs_queue" "order_service_order_deleted" {
  name = "${var.stage_name}-order-service-order-deleted"
  redrive_policy  = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.order_service_order_deleted_dl.arn}\",\"maxReceiveCount\":5}"
  visibility_timeout_seconds = 300
  sqs_managed_sse_enabled = true

    tags = {
        Environment = var.stage_name
    }
}

resource "aws_sqs_queue" "order_service_order_deleted_dl" {
  name = "${var.stage_name}-order-service-order-deleted-dl"
  sqs_managed_sse_enabled = true
}

resource "aws_sns_topic_subscription" "order_deleted_sqs_target" {
  topic_arn = var.order_deleted_sns_arn
  protocol  = "sqs"
  endpoint  = "${aws_sqs_queue.order_service_order_deleted.arn}"
}

resource "aws_sqs_queue_policy" "order_service_order_deleted_policy" {
  queue_url = "${aws_sqs_queue.order_service_order_deleted.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:SendMessage",
      "Resource": "${aws_sqs_queue.order_service_order_deleted.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${var.order_deleted_sns_arn}"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_lambda_event_source_mapping" "order_deleted_event_source_mapping" {
  event_source_arn = aws_sqs_queue.order_service_order_deleted.arn
  function_name    = aws_lambda_function.order_service.arn
  function_response_types = ["ReportBatchItemFailures"]
}