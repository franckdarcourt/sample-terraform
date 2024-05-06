variable "release_packages_bucket_name" {
  description = "Name of the bucket where release packages are stored"
  type        = string
}

variable "stage_name" {
  description = "Stage Name (dev, test, prod)"
  type        = string
}
