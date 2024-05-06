variable "release_packages_bucket_name" {
  description = "Name of the bucket where release packages are stored"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  type        = string
}

variable "stage_name" {
  description = "Stage Name (dev, test, prod)"
  type        = string
}

variable "order_created_sns_arn" {
  description = "ARN of the Order Created SNS topic"
  type        = string
}

variable "order_deleted_sns_arn" {
  description = "ARN of the Order Deleted SNS topic"
  type        = string
}

variable "liveness_endpoint" {
  description = "Endpoint for liveness probe"
  type        = string
  default     = "/live"
}

variable "readiness_endpoint" {
  description = "Endpoint for readiness probe"
  type        = string
  default     = "/ready"
}