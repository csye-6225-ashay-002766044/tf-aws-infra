# Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "MyVPC"
  }
}

# Create Public Subnets
resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "Public-Subnet-${count.index + 1}"
  }
}

# Create Private Subnets
resource "aws_subnet" "private_subnets" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "Private-Subnet-${count.index + 1}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Internet-Gateway"
  }
}

# Create Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "Public-Route-Table"
  }
}

# Attach Public Subnets to Public Route Table
resource "aws_route_table_association" "public_assoc" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Create Public Route
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Create Private Route Table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "Private-Route-Table"
  }
}

# Attach Private Subnets to Private Route Table
resource "aws_route_table_association" "private_assoc" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# Updated Application Security Group
resource "aws_security_group" "app_sg" {
  vpc_id      = aws_vpc.main_vpc.id
  name        = "webapp-security-group"
  description = "Security group for application instances"

  # Allow SSH access only from your IP or VPN
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider restricting this to your IP
    description = "SSH access"
  }

  # Allow traffic on application port only from load balancer
  ingress {
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id]
    description     = "Allow traffic from load balancer to application port"
  }

  # Deny database access from outside the instance
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["127.0.0.1/32"]
    description = "Local MySQL access only"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["127.0.0.1/32"]
    description = "Local PostgreSQL access only"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.vpc_name}-App-SG"
  }
}

# EC2 Instance using Custom AMI - COMMENTED OUT as we're using Auto Scaling now
# resource "aws_instance" "app_instance" {
#   ami                         = var.custom_ami_id
#   instance_type               = "t2.micro"
#   subnet_id                   = aws_subnet.public_subnets[0].id
#   iam_instance_profile        = aws_iam_instance_profile.webapp_combined_profile.name
#   vpc_security_group_ids      = [aws_security_group.app_sg.id]
#   associate_public_ip_address = true
#   user_data                   = <<EOF
# #!/bin/bash
# echo "Starting user data script..."
#
# # Create .env file for the web application
# echo "Setting up environment variables..."
# echo "AWS_REGION=${var.aws_region}" >> /opt/webapp/.env
# echo "S3_BUCKET_NAME=${aws_s3_bucket.webapp_bucket.id}" >> /opt/webapp/.env
# echo "DB_HOST=$(echo ${aws_db_instance.webapp_rds.endpoint} | cut -d ':' -f 1)" >> /opt/webapp/.env
# echo "DB_NAME=csye6225" >> /opt/webapp/.env
# echo "DB_USER=csye6225" >> /opt/webapp/.env
# echo "DB_PASSWORD=${var.db_password}" >> /opt/webapp/.env
#
# echo "Creating CloudWatch config file..."
# cat <<EOC > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
# {
#   "agent": {
#     "metrics_collection_interval": 10,
#     "run_as_user": "cwagent"
#   },
#   "logs": {
#     "logs_collected": {
#       "files": {
#         "collect_list": [
#           {
#             "file_path": "/opt/webapp/webapp.log",
#             "log_group_name": "webapp-logs",
#             "log_stream_name": "{instance_id}",
#             "timestamp_format": "%Y-%m-%d %H:%M:%S"
#           },
#           {
#             "file_path": "/var/log/syslog",
#             "log_group_name": "system-logs",
#             "log_stream_name": "{instance_id}",
#             "timestamp_format": "%b %d %H:%M:%S"
#           }
#         ]
#       }
#     }
#   },
#   "metrics": {
#     "append_dimensions": {
#       "InstanceId": "$${aws:InstanceId}"
#     },
#     "aggregation_dimensions": [["InstanceId"]],
#     "metrics_collected": {
#       "cpu": {
#         "measurement": ["usage_idle", "usage_user", "usage_system"],
#         "metrics_collection_interval": 10
#       },
#       "mem": {
#         "measurement": ["mem_used_percent"],
#         "metrics_collection_interval": 10
#       }
#     }
#   }
# }
# EOC
#
# chmod 444 /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
# chown root:root /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
#
# echo "Applying CloudWatch Agent config..."
# /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
# -a fetch-config \
# -m ec2 \
# -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
# -s
#
# echo "Installing statsd..."
# apt-get update -y
# apt-get install -y statsd
# service statsd start
#
# echo "Restarting application..."
# systemctl restart myapp.service || true
# EOF
# }
