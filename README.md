Terraform AWS Infrastructure Setup

## Overview

This Terraform project automates the provisioning of an AWS Virtual Private Cloud (VPC) with public and private subnets, an internet gateway, and route tables. The setup ensures high availability by distributing subnets across multiple AWS Availability Zones.

## Project Structure

├── main.tf               # Terraform configuration for AWS resources
├── variables.tf          # Variable definitions with default values
├── terraform.tfvars      # Overrides for Terraform variables
├── README.md             # Project documentation

## Prerequisites

Ensure you have the following installed before running Terraform:

Terraform (v1.0+)

AWS CLI (configured with proper access permissions)

An AWS account with IAM permissions to create networking resources

## Configuration

Using terraform.tfvars:

aws_profile = "dev"
aws_region  = "us-east-1"
vpc_cidr    = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]

## Using Environment Variables:

export TF_VAR_aws_region="us-east-1"
export TF_VAR_vpc_cidr="10.0.0.0/16"

## Deployment Steps

Follow these steps to deploy the AWS infrastructure:

Initialize Terraform:
terraform init

Validate terraform:
terraform validate

Preview the changes:
terraform plan

Apply the configuration:
terraform apply

Destroy resources:
terraform destroy 

## Key Features

Automated VPC Creation – Configures a VPC with public and private subnets.
Subnet Distribution – Deploys subnets across multiple Availability Zones.
Internet Connectivity – Configures an Internet Gateway for public subnets.
Routing – Assigns route tables to direct network traffic efficiently.
Customizable – Modify terraform.tfvars to adjust configurations dynamically.