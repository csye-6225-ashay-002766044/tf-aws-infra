# IAM Role for EC2 (Both S3 & CloudWatch Permissions)
resource "aws_iam_role" "webapp_combined_role" {
  name = "WebAppCombinedRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach S3 Policy
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}

# Attach CloudWatch Policy
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}

# Attach AWS-Managed CloudWatchAgentServerPolicy
resource "aws_iam_role_policy_attachment" "attach_managed_cloudwatch_agent_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


# IAM Instance Profile
resource "aws_iam_instance_profile" "webapp_combined_profile" {
  name = "webapp_combined_profile"
  role = aws_iam_role.webapp_combined_role.name
}

# Attach AWS-Managed Route53FullAccess policy
resource "aws_iam_role_policy_attachment" "attach_route53_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

# Attach AWS-Managed ElasticLoadBalancingFullAccess policy
resource "aws_iam_role_policy_attachment" "attach_elb_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

# Attach AWS-Managed AutoScalingFullAccess policy
resource "aws_iam_role_policy_attachment" "attach_autoscaling_policy" {
  role       = aws_iam_role.webapp_combined_role.name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingFullAccess"
}
