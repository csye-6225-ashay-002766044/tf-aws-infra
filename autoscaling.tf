# Launch Template for Auto Scaling Group
resource "aws_launch_template" "webapp_launch_template" {
  name_prefix   = "csye6225_"
  image_id      = var.custom_ami_id
  instance_type = "t2.micro"
  key_name      = var.ssh_username

  iam_instance_profile {
    name = aws_iam_instance_profile.webapp_combined_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }

  # Add EBS encryption with KMS
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 8
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
      kms_key_id            = aws_kms_key.ec2_kms.arn
    }
  }

  user_data = base64encode(<<EOF
#!/bin/bash
exec > >(tee -a /var/log/user_data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -e
echo "Starting user data script..."

apt-get update -y

# Install AWS CLI if needed
if ! command -v aws &>/dev/null; then
  apt-get install -y unzip curl
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
fi

# Install jq if needed
if ! command -v jq &>/dev/null; then
  apt-get install -y jq
fi

# Retrieve secrets
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id ${aws_secretsmanager_secret.db_secret.name} \
  --region ${var.aws_region} \
  --query SecretString --output text)

# Create .env file
mkdir -p /opt/webapp
echo "$SECRET_JSON" | jq -r 'to_entries|map("\(.key)=\(.value|tostring)")|.[]' > /opt/webapp/.env
echo "AWS_REGION=${var.aws_region}" >> /opt/webapp/.env
echo "S3_BUCKET_NAME=${aws_s3_bucket.webapp_bucket.id}" >> /opt/webapp/.env

chmod 600 /opt/webapp/.env
chown csye6225:csye6225 /opt/webapp/.env

# CloudWatch Agent config
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat <<EOC > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": { "metrics_collection_interval": 10, "run_as_user": "cwagent" },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          { "file_path": "/opt/webapp/webapp.log", "log_group_name": "webapp-logs", "log_stream_name": "{instance_id}", "timestamp_format": "%Y-%m-%d %H:%M:%S" },
          { "file_path": "/var/log/syslog", "log_group_name": "system-logs", "log_stream_name": "{instance_id}", "timestamp_format": "%b %d %H:%M:%S" },
          { "file_path": "/var/log/user_data.log", "log_group_name": "userdata-logs", "log_stream_name": "{instance_id}", "timestamp_format": "%Y-%m-%d %H:%M:%S" }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": { "InstanceId": "$${aws:InstanceId}" },
    "aggregation_dimensions": [["InstanceId"]],
    "metrics_collected": {
      "cpu": { "measurement": ["usage_idle", "usage_user", "usage_system"], "metrics_collection_interval": 10 },
      "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 10 }
    }
  }
}
EOC

chmod 444 /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
chown root:root /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Install statsd
apt-get install -y statsd
service statsd start

# Wait to ensure dependencies are ready
sleep 30

# Reload systemd and enable the service
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable webapp.service

# Retry logic for service startup
for retry in {1..5}; do
  echo "Attempt $retry to start webapp.service"
  systemctl restart webapp.service
  sleep 15

  if systemctl is-active --quiet webapp.service; then
    echo "webapp.service started successfully!"
    break
  else
    echo "Retry $retry failed. Waiting and retrying..."
    sleep 10
  fi
done

if systemctl is-active --quiet webapp.service; then
  echo "FINAL CHECK: Service is active."
else
  echo "FINAL CHECK: Service failed. Dumping logs..."
  systemctl status webapp.service >> /opt/webapp/service-status.log
  journalctl -u webapp.service --no-pager -n 50 >> /opt/webapp/service-status.log
  echo "Retrying with extended wait..."
  sleep 20
  systemctl restart webapp.service
fi

EOF
  )



  depends_on = [
    aws_kms_key.ec2_kms,
    aws_kms_key.rds_kms,
    aws_kms_key.s3_kms,
    aws_kms_key.secrets_kms,
    aws_db_instance.webapp_rds,
    aws_iam_instance_profile.webapp_combined_profile
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "WebApp-ASG-Instance"
    }
  }
}

# Rest of the file remains the same (Auto Scaling Group, Scaling Policies, etc.)
# Auto Scaling Group
resource "aws_autoscaling_group" "webapp_asg" {
  name                = "csye6225_asg"
  min_size            = 3
  max_size            = 5
  desired_capacity    = 3
  default_cooldown    = 60
  vpc_zone_identifier = aws_subnet.public_subnets[*].id

  launch_template {
    id      = aws_launch_template.webapp_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.webapp_tg.arn]

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 90
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "WebApp-ASG-Instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
}

# Scale up policy
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "cpu-usage-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "Scale up if CPU usage is above 10% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}

# Scale down policy
resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.webapp_asg.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "cpu-usage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "7"
  alarm_description   = "Scale down if CPU usage is below 7% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}
