variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier used for resource naming and tagging"
  type        = string
  default     = "workload-migration"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "poc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for migration source and target hosts"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port exposed by the application"
  type        = number
  default     = 5000
}

variable "image_tag" {
  description = "Container image tag published to ECR"
  type        = string
  default     = "1.0.0"
}

variable "deploy_ecs" {
  description = "Controls ECS provisioning. Enable only after the image is available in ECR."
  type        = bool
  default     = false
}
