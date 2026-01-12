output "ecr_url" { value = aws_ecr_repository.api.repository_url }
output "alb_dns" { value = aws_lb.main.dns_name }
output "cluster_name" { value = aws_ecs_cluster.portfolio.name }
output "service_name" { value = aws_ecs_service.api.name }
output "task_family" { value = aws_ecs_task_definition.api.family }
