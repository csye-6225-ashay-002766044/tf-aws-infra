resource "aws_security_group" "db_sg" {
  name        = "database-security-group"
  description = "Security group for RDS database instance"
  vpc_id      = aws_vpc.main_vpc.id # Ensure it belongs to the same VPC


  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  # No Public Internet Access to RDS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS-Security-Group"
  }
}
