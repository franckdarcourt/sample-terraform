terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = var.region
}

module "order" {
  source                          = "./modules/order"
  release_packages_bucket_name    = var.release_packages_bucket_name
  cognito_user_pool_arn           = module.user.cognito_userpool_arn
  order_created_sns_arn           = aws_sns_topic.order_created.arn
  order_deleted_sns_arn           = aws_sns_topic.order_deleted.arn
  stage_name                      = var.stage_name
}

module "product" {
  source                              = "./modules/product"
  release_packages_bucket_name        = var.release_packages_bucket_name
  stage_name                          = var.stage_name
}
