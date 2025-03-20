# 🏗️ Create RDS Security Group
resource "aws_security_group" "db_sg" {
  name        = "database-security-group"
  description = "Security group for RDS database instance"
  vpc_id      = aws_vpc.main_vpc.id # Ensure it belongs to the same VPC

  # ✅ Allow inbound traffic from Application Security Group
  ingress {
    from_port       = 3306 # MySQL Port (Use 5432 for PostgreSQL)
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id] # ✅ Only allow traffic from App SG
  }

  # ❌ No Public Internet Access to RDS
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # ✅ RDS can access the internet if needed (e.g., for updates)
  }

  tags = {
    Name = "RDS-Security-Group"
  }
}
