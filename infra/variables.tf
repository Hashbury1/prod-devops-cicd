variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ecr_repository_name" {
  description = "ECR repository name"
  type        = string
  default     = "portfolio-api"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
  default     = "portfolio-cluster"
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
  default     = "portfolio-service"
}

variable "ecs_task_family" {
  description = "ECS task definition family"
  type        = string
  default     = "portfolio-api"
}

variable "container_name" {
  description = "Container name"
  type        = string
  default     = "api"
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "fargate_cpu" {
  description = "Fargate CPU"
  type        = string
  default     = "256"
}

variable "fargate_memory" {
  description = "Fargate memory"
  type        = string
  default     = "512"
}

variable "service_desired_count" {
  description = "ECS service desired count"
  type        = number
  default     = 1
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs"
  type        = list(string)
}
