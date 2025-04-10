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

  # User data for instance configuration
  user_data = base64encode(<<EOF
#!/bin/bash
echo "Starting user data script..."

# Create .env file for the web application
echo "Setting up environment variables..."
echo "AWS_REGION=${var.aws_region}" >> /opt/webapp/.env
echo "S3_BUCKET_NAME=${aws_s3_bucket.webapp_bucket.id}" >> /opt/webapp/.env
echo "DB_HOST=$(echo ${aws_db_instance.webapp_rds.endpoint} | cut -d ':' -f 1)" >> /opt/webapp/.env
echo "DB_NAME=csye6225" >> /opt/webapp/.env
echo "DB_USER=csye6225" >> /opt/webapp/.env
echo "DB_PASSWORD=${var.db_password}" >> /opt/webapp/.env

echo "Creating CloudWatch config file..."
cat <<EOC > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 10,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/opt/webapp/webapp.log",
            "log_group_name": "webapp-logs",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "system-logs",
            "log_stream_name": "{instance_id}",
            "timestamp_format": "%b %d %H:%M:%S"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    },
    "aggregation_dimensions": [["InstanceId"]],
    "metrics_collected": {
      "cpu": {
        "measurement": ["usage_idle", "usage_user", "usage_system"],
        "metrics_collection_interval": 10
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 10
      }
    }
  }
}
EOC

chmod 444 /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
chown root:root /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Applying CloudWatch Agent config..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
-a fetch-config \
-m ec2 \
-c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
-s

echo "Installing statsd..."
apt-get update -y
apt-get install -y statsd
service statsd start

echo "Restarting application..."
systemctl restart myapp.service || true
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "WebApp-ASG-Instance"
    }
  }
}

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

  # Add any additional tags required for your environment
  tag {
    key                 = "Environment"
    value               = "Production"
    propagate_at_launch = true
  }
}

# Scale up policy - CPU Usage Above 5%
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
  alarm_description   = "Scale up if CPU usage is above 5% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}


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
  alarm_description   = "Scale down if CPU usage is below 3% for 1 minute"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webapp_asg.name
  }
}


