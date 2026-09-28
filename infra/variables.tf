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
  description = "EC2 instance type for the app server"
  type        = string
  default     = "t3.small"
}

variable "budget_email" {
  description = "Email that receives the budget alerts (set in terraform.tfvars, never committed)"
  type        = string
}
