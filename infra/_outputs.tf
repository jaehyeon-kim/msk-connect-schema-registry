# VPC
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# CIDR blocks
output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

# Subnets
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# NAT gateways
output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = module.vpc.nat_public_ips
}

# AZs
output "azs" {
  description = "A list of availability zones specified as argument to this module"
  value       = module.vpc.azs
}

# AutoScaling
output "vpn_launch_template_arn" {
  description = "The ARN of the VPN launch template"
  value = {
    for k, v in module.vpn : k => v.launch_template_arn
  }
}

output "vpn_autoscaling_group_id" {
  description = "VPN autoscaling group id"
  value = {
    for k, v in module.vpn : k => v.autoscaling_group_id
  }
}

output "vpn_autoscaling_group_name" {
  description = "VPN autoscaling group name"
  value = {
    for k, v in module.vpn : k => v.autoscaling_group_name
  }
}

# RDS
output "cluster_arn" {
  description = "Amazon Resource Name (ARN) of cluster"
  value       = module.aurora.cluster_arn
}

output "db_subnet_group_name" {
  description = "The db subnet group name"
  value       = module.aurora.db_subnet_group_name
}

output "cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = module.aurora.cluster_endpoint
}

output "cluster_engine_version_actual" {
  description = "The running version of the cluster database"
  value       = module.aurora.cluster_engine_version_actual
}

output "cluster_database_name" {
  description = "Name for an automatically created database on cluster creation"
  value       = module.aurora.cluster_database_name
}

output "cluster_instances" {
  description = "A map of cluster instances and their attributes"
  value       = module.aurora.cluster_instances
}

output "cluster_security_group_id" {
  description = "The security group ID of the cluster"
  value       = module.aurora.security_group_id
}

output "cluster_db_access_security_group_id" {
  description = "The security group id for VPN access"
  value       = var.aurora_create ? aws_security_group.db_access[0].id : null
}

# Registry
output "registry_ecs_cluster_arn" {
  description = "The ECS cluster ARN for registry service"
  value       = var.registry_create ? aws_ecs_cluster.registry_ecs_cluster[0].arn : null
}

output "registry_service_arn" {
  description = "The registry service ARN"
  value       = var.registry_create ? aws_ecs_service.registry_service[0].id : null
}

output "registry_lb_arn" {
  description = "The ARN of the load balancer for registry service"
  value       = var.registry_create ? aws_lb.registry_lb[0].arn : null
}

output "registry_lb_dns_name" {
  description = "The DNS name of the load balancer for registry service"
  value       = var.registry_create ? aws_lb.registry_lb[0].dns_name : null
}

# MSK
output "msk_arn" {
  description = "Amazon Resource Name (ARN) of the MSK cluster"
  value       = var.msk_create ? aws_msk_cluster.msk_data_cluster[0].arn : null
}

output "msk_bootstrap_brokers_sasl_iam" {
  description = "One or more DNS names (or IP addresses) and SASL IAM port pairs"
  value       = var.msk_create ? aws_msk_cluster.msk_data_cluster[0].bootstrap_brokers_sasl_iam : null
}

output "msk_connect_role_arn" {
  description = "Amazon Resource Name (ARN) of the IAM role for connectors"
  value       = var.msk_create ? aws_iam_role.msk_connect_role[0].arn : null
}

# S3
output "s3_data_bucket_arn" {
  description = "The ARN of the data bucket"
  value       = aws_s3_bucket.data_bucket.arn
}
