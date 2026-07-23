output "source_instance_id" {
  description = "Instance ID of the migration source host"
  value       = aws_instance.source.id
}

output "source_public_ip" {
  description = "Public IP of the migration source host"
  value       = aws_instance.source.public_ip
}

output "target_instance_id" {
  description = "Instance ID of the migration target host"
  value       = aws_instance.target.id
}

output "target_public_ip" {
  description = "Public IP of the migration target host"
  value       = aws_instance.target.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for the containerized workload"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name, available after enabling deploy_ecs"
  value       = var.deploy_ecs ? aws_ecs_cluster.main[0].name : null
}

output "ecs_service_name" {
  description = "ECS service name, available after enabling deploy_ecs"
  value       = var.deploy_ecs ? aws_ecs_service.app[0].name : null
}
