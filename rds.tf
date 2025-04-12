resource "aws_db_parameter_group" "webapp_db_pg" {
  name   = "csye6225-db-param-group"
  family = "mysql8.0" # Change based on DB engine: mysql8.0, mariadb10.6, postgres13

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "max_connections"
    value = "100"
  }

  tags = {
    Name        = "csye6225-db-param-group"
    Environment = "Production"
  }
}

resource "aws_db_subnet_group" "webapp_db_subnet_group" {
  name       = "csye6225-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id # Uses the private subnets from VPC

  tags = {
    Name = "csye6225-db-subnet-group"
  }
}

# Security group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "csye6225-db-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main_vpc.id

  # Allow MySQL/MariaDB (3306) only from the App Security Group
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Restricts access to only the EC2 instance
  }

  tags = {
    Name = "csye6225-db-sg"
  }
}

# Random ID for the database identifier
resource "random_id" "db_identifier_suffix" {
  byte_length = 4
}

# Updated RDS instance with KMS encryption and random password from Secrets Manager
resource "aws_db_instance" "webapp_rds" {
  identifier             = "csye6225-${random_id.db_identifier_suffix.hex}"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = "csye6225"
  db_name                = "csye6225"
  password               = random_password.db_password.result # Use the random password
  parameter_group_name   = aws_db_parameter_group.webapp_db_pg.name
  db_subnet_group_name   = aws_db_subnet_group.webapp_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  multi_az               = false
  skip_final_snapshot    = true

  # Enable KMS encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds_kms.arn

  tags = {
    Name = "csye6225-db-instance"
  }
}
