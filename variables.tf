variable "aws_profile" {
  description = "AWS profile to use for authentication"
  type        = string
  default     = "dev"
}


# AWS Region
variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "MyVPC"
}

# Public Subnets
variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

# Private Subnets
variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Availability Zones
variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Application Port
variable "app_port" {
  description = "Port on which the application runs"
  type        = number
  default     = 8080
}

# Custom AMI ID
variable "custom_ami_id" {
  description = "ID of the custom AMI to use for the EC2 instance"
  type        = string
}

# Source AMI for Packer Build
variable "source_ami" {
  description = "Source AMI for building a custom image"
  type        = string
}

# SSH Username
variable "ssh_username" {
  description = "The SSH username for the instance"
  type        = string
  default     = "ec2-user"
}
