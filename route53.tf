# Add a variable for environment (dev/demo)
variable "environment" {
  description = "Environment (dev or demo)"
  type        = string
  default     = "demo" # or "demo" based on your environment
}

# Route53 zone data source (assuming the zone already exists)
# data "aws_route53_zone" "domain_zone" {
#   name         = var.domain_name
#   private_zone = false
# }

# Route53 A record for the load balancer
resource "aws_route53_record" "webapp_dns" {
  zone_id = "Z00210731J87S2314QQML"
  name    = "demo.ashaysaoji.com"
  type    = "A"

  alias {
    name                   = aws_lb.webapp_lb.dns_name
    zone_id                = aws_lb.webapp_lb.zone_id
    evaluate_target_health = true
  }
}
