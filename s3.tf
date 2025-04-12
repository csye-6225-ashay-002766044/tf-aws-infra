locals {
  unique_bucket_name = "${var.s3_bucket_name}-${uuid()}"
}

resource "aws_s3_bucket" "webapp_bucket" {
  bucket        = local.unique_bucket_name
  force_destroy = true

  tags = {
    Name        = local.unique_bucket_name
    Environment = "Production"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.webapp_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Updated encryption configuration to use KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.webapp_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_kms.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.webapp_bucket.id

  rule {
    id     = "move-to-ia"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

# Updated IAM policy for S3 access with KMS permissions
resource "aws_iam_policy" "s3_access_policy" {
  name        = "WebAppS3Policy"
  description = "Allow EC2 instance to access S3 bucket with KMS encryption"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.webapp_bucket.id}",
          "arn:aws:s3:::${aws_s3_bucket.webapp_bucket.id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = [
          aws_kms_key.s3_kms.arn
        ]
      }
    ]
  })
}

# Attach S3 policy to the existing IAM role
resource "aws_iam_role_policy_attachment" "attach_s3_kms_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}
