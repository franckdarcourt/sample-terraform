output "order_setup_api_execution_arn" {
  description = "Execution ARN of the Order API"
  value       = aws_api_gateway_stage.order_setup_api.execution_arn
}

output "api_execution_arn" {
  description = "Execution ARN of the Order API"
  value       = aws_api_gateway_stage.order_setup_api.execution_arn
}

output "api_id" {
  description = "ID of the Order API"
  value       = aws_api_gateway_rest_api.order_setup_api.id
}

output "order_setup_bucket" {
  description = "Bucket Name of the Order API"
  value       = aws_s3_bucket.bucket.id
}

output "order_setup_bucket_arn" {
  description = "Bucket ARN of the Order API"
  value       = aws_s3_bucket.bucket.arn
}

output "order_setup_api_creation_endpoint" {
  description = "Endpoint of order api creation request"
  value       = "${aws_api_gateway_stage.order_setup_api.execution_arn}/POST/api/orders"
}
