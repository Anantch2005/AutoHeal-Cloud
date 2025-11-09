######################################################
# Load Balancer DNS Outputs
######################################################

output "primary_alb_dns" {
  description = "DNS name of the primary ALB"
  value       = aws_lb.primary_alb.dns_name
}

output "secondary_alb_dns" {
  description = "DNS name of the secondary ALB"
  value       = aws_lb.secondary_alb.dns_name
}

######################################################
# Global Accelerator Outputs
######################################################

output "global_accelerator_dns" {
  description = "DNS name of the Global Accelerator"
  value       = aws_globalaccelerator_accelerator.main.dns_name
}

output "global_accelerator_ip" {
  description = "Static IPs of the Global Accelerator"
  value       = aws_globalaccelerator_accelerator.main.ip_sets[0].ip_addresses
}

######################################################
# EC2 Instance Public IPs (for Ansible inventory)
######################################################

# Fetch EC2 instances from primary region 
data "aws_instances" "primary" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.primary_asg.name]
  }
}

# Fetch EC2 instances from secondary region
data "aws_instances" "secondary" {
  provider = aws.secondary

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.secondary_asg.name]
  }
}

# Primary EC2 Public IPs
output "primary_ec2_public_ips" {
  description = "Public IPs of EC2s in the primary region"
  value       = data.aws_instances.primary.public_ips
}

# Secondary EC2 Public IPs
output "secondary_ec2_public_ips" {
  description = "Public IPs of EC2s in the secondary region"
  value       = data.aws_instances.secondary.public_ips
}
