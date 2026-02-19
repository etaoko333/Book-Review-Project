output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_alb_dns" {
  description = "PUBLIC ALB DNS — open this in browser"
  value       = "http://${aws_lb.public.dns_name}"
}

output "internal_alb_dns" {
  description = "Internal ALB DNS (App Tier)"
  value       = aws_lb.internal.dns_name
}

output "web_ec2_public_ip" {
  description = "Web Tier EC2 public IP"
  value       = aws_instance.web.public_ip
}

output "app_ec2_private_ip" {
  description = "App Tier EC2 private IP"
  value       = aws_instance.app.private_ip
}

output "rds_primary_endpoint" {
  description = "RDS Primary endpoint"
  value       = aws_db_instance.primary.endpoint
}

output "rds_primary_hostname" {
  description = "RDS Primary hostname"
  value       = aws_db_instance.primary.address
}

output "rds_replica_endpoint" {
  description = "RDS Read Replica endpoint"
  value       = aws_db_instance.replica.endpoint
}

output "rds_multi_az" {
  description = "RDS Multi-AZ enabled"
  value       = aws_db_instance.primary.multi_az
}

output "sg_chain" {
  description = "Security Group chain"
  value = {
    public_alb   = aws_security_group.public_alb.id
    web_ec2      = aws_security_group.web.id
    internal_alb = aws_security_group.internal_alb.id
    app_ec2      = aws_security_group.app.id
    db_rds       = aws_security_group.db.id
  }
}

output "ssh_web" {
  description = "SSH into Web EC2"
  value       = "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_instance.web.public_ip}"
}

output "ssh_app_via_web" {
  description = "SSH into App EC2 via Web (bastion hop)"
  value       = "ssh -i ${var.key_pair_name}.pem -J ubuntu@${aws_instance.web.public_ip} ubuntu@${aws_instance.app.private_ip}"
}