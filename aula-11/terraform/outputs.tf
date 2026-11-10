output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "listener_arn" {
  description = "ARN of the ALB Listener"
  value       = aws_lb_listener.main.arn
}

output "blue_tg_arn" {
  description = "ARN of the Blue Target Group"
  value       = aws_lb_target_group.blue.arn
}

output "blue_tg_name" {
  description = "Name of the Blue Target Group"
  value       = aws_lb_target_group.blue.name
}

output "green_tg_arn" {
  description = "ARN of the Green Target Group"
  value       = aws_lb_target_group.green.arn
}

output "green_tg_name" {
  description = "Name of the Green Target Group"
  value       = aws_lb_target_group.green.name
}

output "alb_security_group_id" {
  description = "Security Group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "instance_security_group_id" {
  description = "Security Group ID for EC2 instances"
  value       = aws_security_group.instance.id
}

output "instance_port" {
  description = "Port that instances listen on"
  value       = var.instance_port
}

output "alb_port" {
  description = "Port that ALB listens on"
  value       = var.alb_port
}
