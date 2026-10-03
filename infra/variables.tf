variable "region" {
  description = "AWS region where all resources are created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used in resource Name tags"
  type        = string
  default     = "clouddrop"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the app server. 8 GB fits Argo CD and Prometheus (t3.small's 2 GB ran out); free plan accounts only allow free-tier types"
  type        = string
  default     = "m7i-flex.large"
}

variable "budget_email" {
  description = "Email that receives the budget alerts (set in terraform.tfvars, never committed)"
  type        = string
}
