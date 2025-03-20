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

# security

resource "aws_security_group" "rds_sg" {
  name        = "csye6225-db-security-group"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main_vpc.id

  # Allow MySQL/MariaDB (3306) or PostgreSQL (5432) only from the App Security Group
  ingress {
    from_port       = 3306 # Change to 5432 for PostgreSQL
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # Restricts access to only the EC2 instance
  }

  tags = {
    Name = "csye6225-db-sg"
  }
}

resource "aws_db_instance" "webapp_rds" {
  identifier             = "csye6225"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  username               = "csye6225"
  db_name                = "csye6225"
  password               = var.db_password # Store securely in Terraform variables
  parameter_group_name   = aws_db_parameter_group.webapp_db_pg.name
  db_subnet_group_name   = aws_db_subnet_group.webapp_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false # Keep it private
  multi_az               = false # No need for Multi-AZ in this case
  skip_final_snapshot    = true

  tags = {
    Name = "csye6225-db-instance"
  }
}




