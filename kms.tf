# Get current account identity for KMS policies
data "aws_caller_identity" "current" {}

# KMS Key for EC2
resource "aws_kms_key" "ec2_kms" {
  description             = "KMS for EC2"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ec2_kms_policy.json
}

data "aws_iam_policy_document" "ec2_kms_policy" {
  statement {
    sid    = "AllowRootFullAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEC2Service"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowAutoScalingService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
    actions   = ["kms:CreateGrant"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowServiceLinkedRoleAutoScaling"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
      ]
    }
    actions = [
      "kms:CreateGrant",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AllowAppRoleAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.webapp_combined_role.arn]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_alias" "ec2_kms" {
  name          = "alias/ec2_kms_${random_id.kms_suffix.hex}"
  target_key_id = aws_kms_key.ec2_kms.key_id
}

# KMS Key for RDS
resource "aws_kms_key" "rds_kms" {
  description             = "KMS for RDS"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = format("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id)
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRDSServiceUse"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAppRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.webapp_combined_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "rds-kms-key"
  }
}

resource "aws_kms_alias" "rds_kms" {
  name          = "alias/rds_kms_${random_id.kms_suffix.hex}"
  target_key_id = aws_kms_key.rds_kms.key_id
}

# KMS Key for S3
resource "aws_kms_key" "s3_kms" {
  description             = "KMS for S3 bucket"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = format("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id)
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowS3ServiceAccess"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAppRoleAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.webapp_combined_role.arn
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "s3-kms-key"
  }
}

resource "aws_kms_alias" "s3_kms" {
  name          = "alias/s3_kms_${random_id.kms_suffix.hex}"
  target_key_id = aws_kms_key.s3_kms.key_id
}

# KMS Key for Secrets Manager
resource "aws_kms_key" "secrets_kms" {
  description             = "KMS for Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowRootFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = format("arn:aws:iam::%s:root", data.aws_caller_identity.current.account_id)
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowSecretsManagerUse"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowEC2ToDecryptSecrets"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.webapp_combined_role.arn
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "secrets-kms-key"
  }
}

resource "aws_kms_alias" "secrets_kms" {
  name          = "alias/secrets_kms_${random_id.kms_suffix.hex}"
  target_key_id = aws_kms_key.secrets_kms.key_id
}

# Create a KMS access policy for the EC2 role
resource "aws_iam_policy" "kms_access_policy" {
  name        = "WebAppKMSPolicy"
  description = "Allow EC2 instances to use KMS keys for encryption/decryption"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ],
        Resource = [
          aws_kms_key.ec2_kms.arn,
          aws_kms_key.rds_kms.arn,
          aws_kms_key.s3_kms.arn,
          aws_kms_key.secrets_kms.arn
        ]
      }
    ]
  })
}

# Attach the KMS policy to the role
resource "aws_iam_role_policy_attachment" "attach_kms_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = aws_iam_policy.kms_access_policy.arn
}

# Random ID for unique naming
resource "random_id" "kms_suffix" {
  byte_length = 4
}
