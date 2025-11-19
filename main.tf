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

provider "aws" {
  alias  = "replica"
  region = "us-east-2"
}

provider "aws" {
  alias  = "replica_logs_target"
  region = "us-west-1"
}

data "aws_caller_identity" "current" {}

locals {
  name_prefix = lower(replace(replace(split("/", data.aws_caller_identity.current.arn)[1], "-", ""), ".", ""))
  account_id  = data.aws_caller_identity.current.account_id
}

resource "aws_kms_key" "s3" {
  description         = "Customer-managed key for S3 encryption"
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3Usage",
        Effect    = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action    = [
          "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
        ],
        Resource  = "*"
      },
      {
        Sid       = "AllowAccountAccess",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "example" {
  bucket        = format("%s-example-bucket-%s", local.name_prefix, local.account_id)
  force_destroy = true
  tags = {
    Owner       = local.name_prefix
    Environment = "dev"
    Purpose     = "Example bucket"
  }
}

resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example_encryption" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
  depends_on = [aws_kms_key.s3]
}

resource "aws_s3_bucket_logging" "example_logging" {
  bucket        = aws_s3_bucket.example.id
  target_bucket = aws_s3_bucket.replica_logs_target.id
  target_prefix = "log/"
}

resource "aws_s3_bucket_lifecycle_configuration" "example_lifecycle" {
  bucket = aws_s3_bucket.example.id
  rule {
    id     = "expire-example"
    status = "Enabled"
    filter { prefix = "" }
    expiration { days = 180 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

resource "aws_s3_bucket_notification" "example_notify" {
  bucket     = aws_s3_bucket.example.id
  depends_on = [aws_s3_bucket.example]
}

resource "aws_iam_role" "replication_role" {
  name = format("%s-s3-replication-role", local.name_prefix)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "s3.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  name = "s3-replication-policy"
  role = aws_iam_role.replication_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:GetReplicationConfiguration", "s3:ListBucket"],
        Resource = [aws_s3_bucket.s3_tf.arn]
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObjectVersion", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"],
        Resource = ["${aws_s3_bucket.s3_tf.arn}/*"]
      },
      {
        Effect = "Allow",
        Action = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"],
        Resource = ["${aws_s3_bucket.replica.arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "s3_tf_replication" {
  bucket = aws_s3_bucket.s3_tf.id
  role   = aws_iam_role.replication_role.arn
  rule {
    id     = "replicate"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
    filter { prefix = "" }
  }

  depends_on = [
    aws_s3_bucket_versioning.s3_tf,
    aws_s3_bucket_versioning.replica
  ]
}