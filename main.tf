terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "sctp-ce11-tfstate"
    key    = "shilpa/s3-tfstate/terraform.tfstate"  #"shilpa-s3-tf-ci.tfstate" # Updated for clarity and structure
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  raw_name     = split("/", data.aws_caller_identity.current.arn)[1]
  name_prefix = lower(replace(replace(raw_name, "-", ""), ".", ""))
  account_id   = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "s3_tf" {
  bucket = "${local.name_prefix}-s3-tf-bkt-${local.account_id}"

  tags = {
    Owner       = local.name_prefix
    Environment = "dev"
    Purpose     = "Terraform state bucket"
  }
}

resource "aws_s3_bucket_versioning" "s3_tf_versioning" {
  bucket = aws_s3_bucket.s3_tf.id

  versioning_configuration {
    status = "Enabled"
  }
}