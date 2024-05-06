variable "region" {
  type        = string
  description = "This is populated in every vending machine workspace"
}

variable "stage_name" {
  description = "Stage Name (dev, test, prod)"
  default     = "dev"
  type        = string
}

variable "release_packages_bucket_name" {
  description = "Name of the bucket where release packages are stored"
  type        = string
}

variable "app_lifecycle" {
  type = string
  validation {
    condition = contains([
      "dev",
      "test",
      "perf",
      "stage",
      "prod"], var.app_lifecycle)
    error_message = "Invalid app_lifecycle specified."
  }
  description = "The application lifecycle this cluster serves: 'dev', 'test', perf', 'stage', or 'prod'"
  default     = "dev"
}