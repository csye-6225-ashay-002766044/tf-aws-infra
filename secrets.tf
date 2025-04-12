# Generate a random password for the database
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Random suffix for secret names
resource "random_id" "secret_suffix" {
  byte_length = 4
}

# Database secret
resource "aws_secretsmanager_secret" "db_secret" {
  name                    = "db-secret-${random_id.secret_suffix.hex}"
  description             = "Database credentials for CSYE6225 web application"
  kms_key_id              = aws_kms_key.secrets_kms.arn
  recovery_window_in_days = 7

  tags = {
    Name        = "DB Secret"
    Application = "CSYE6225"
  }
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    DB_USER     = "csye6225"
    DB_PASSWORD = random_password.db_password.result
    DB_DIALECT  = "mysql"
    DB_HOST     = aws_db_instance.webapp_rds.address
    DB_PORT     = 3306
    DB_NAME     = "csye6225"
  })
}


# Add SecretsManager permissions to the existing IAM role policy
resource "aws_iam_policy" "secrets_access_policy" {
  name        = "WebAppSecretsPolicy"
  description = "Allow EC2 instances to access secrets in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = [
          aws_secretsmanager_secret.db_secret.arn,
        ]
      }
    ]
  })
}

# Attach the secrets access policy to your existing IAM role
resource "aws_iam_role_policy_attachment" "attach_secrets_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = aws_iam_policy.secrets_access_policy.arn
}
