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
    key    = "shilpa/s3-tfstate/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

locals {
  # name_prefix = "${split("/", "${data.aws_caller_identity.current.arn}")[1]}"
  # account_id  = "${data.aws_caller_identity.current.account_id}"
  raw_name    = split("/", data.aws_caller_identity.current.arn)[1]
  name_prefix = lower(replace(replace(raw_name, "-", ""), ".", ""))
  account_id  = data.aws_caller_identity.current.account_id
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

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_tf_encryption" {
  bucket = aws_s3_bucket.s3_tf.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3_tf_block" {
  bucket                  = aws_s3_bucket.s3_tf.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "s3_tf_logs" {
  bucket = "${local.name_prefix}-s3-tf-logs-${local.account_id}"
}

resource "aws_s3_bucket_logging" "s3_tf_logging" {
  bucket        = aws_s3_bucket.s3_tf.id
  target_bucket = aws_s3_bucket.s3_tf_logs.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_lifecycle_configuration" "s3_tf_lifecycle" {
  bucket = aws_s3_bucket.s3_tf.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Optional: Event notification placeholder (requires Lambda or SNS/SQS setup)
# resource "aws_s3_bucket_notification" "s3_tf_notify" {
#   bucket = aws_s3_bucket.s3_tf.id
#   lambda_function {
#     lambda_function_arn = aws_lambda_function.example.arn
#     events              = ["s3:ObjectCreated:*"]
#   }
# }

# Optional: Cross-region replication placeholder (requires IAM role and destination bucket)
# resource "aws_s3_bucket_replication_configuration" "s3_tf_replication" {
#   bucket = aws_s3_bucket.s3_tf.id
#   role   = aws_iam_role.replication_role.arn
#   rules {
#     id     = "replicate"
#     status = "Enabled"
#     destination {
#       bucket        = aws_s3_bucket.replica.arn
#       storage_class = "STANDARD"
#     }
#     filter {
#       prefix = ""
#     }
#   }
# }