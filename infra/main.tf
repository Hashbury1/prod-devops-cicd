terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


# Cloud Provider
provider "aws" {
  region = "us-east-1"
}

# Data sources
data "aws_vpcs" "available" {
  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_vpc" "selected" {
  id = data.aws_vpcs.available.ids[0]
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# ECR Repository
resource "aws_ecr_repository" "portfolio_api" {
  name                 = "portfolio-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "portfolio" {
  name = "portfolio-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Task IAM Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "portfolio-cluster-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# - ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attached AWS managed policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution" { 
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



# ECS Security Group
data "aws_security_group" "alb" {
  id = "sg-0e140bec6de28cd10"  # 
}

resource "aws_security_group" "ecs_tasks" {
  name_prefix = "portfolio-ecs-tasks-"
  vpc_id      = "vpc-055f4b07b3ebbb1bb" 

  # Reference the data source correctly
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [data.aws_security_group.alb.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "portfolio-ecs-tasks"
  }
}


# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/portfolio-cluster"
  retention_in_days = 7
}

#Data source
data "aws_caller_identity" "current" {}

resource "aws_ecs_task_definition" "portfolio_api" {
  family                   = "portfolio-api-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name  = "portfolio-api"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/portfolio-api:latest"
      
      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]
      
      # Add logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/portfolio-api"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}



# ECS Service  
resource "aws_ecs_service" "portfolio_api" {
  name            = "portfolio-service-v2"
  cluster         = "arn:aws:ecs:us-east-1:721912316979:cluster/portfolio-cluster"
  task_definition = aws_ecs_task_definition.portfolio_api.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  # Network config goes HERE (inside service block)
  network_configuration {
    subnets          = ["subnet-05dc7473a3e87bb28", "subnet-05ac53e23e072eadb"]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:721912316979:targetgroup/portfolio-api/6bc797771e5549c7"
    container_name   = "portfolio-api"
    container_port   = 8080
  }
}


# IAM policy Attached
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# Data source for AWS subnet

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["private-*"]
  }
}
