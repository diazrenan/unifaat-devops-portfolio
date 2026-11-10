variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "blue-green-app"
}

variable "instance_port" {
  description = "Port that instances listen on"
  type        = number
  default     = 3000
}

variable "alb_port" {
  description = "Port that ALB listens on"
  type        = number
  default     = 80
}

variable "alb_https_port" {
  description = "Port for HTTPS (ALB)"
  type        = number
  default     = 443
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required before considering an unhealthy target healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering the target unhealthy"
  type        = number
  default     = 3
}

variable "stickiness_enabled" {
  description = "Enable stickiness"
  type        = bool
  default     = true
}

variable "stickiness_duration" {
  description = "Stickiness duration in seconds"
  type        = number
  default     = 86400
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "blue-green-deployment"
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}
