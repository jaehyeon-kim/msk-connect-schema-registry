variable "aws_region" {
  default = "ap-southeast-2"
}

variable "environment" {
  description = "Development environment"
  default     = "dev"
}

variable "owner" {
  description = "Owner of the stack"
  default     = "jaehyeon"
}

variable "resource_prefix" {
  description = "Prefix that is added to resource names"
  default     = "analytics"
}

variable "class_b" {
  description = "Class B of VPC (10.XXX.0.0/16)"
  default     = "100"
}

variable "key_pair_create" {
  description = "Whether to create a key pair"
  default     = true
}

variable "vpn_create" {
  description = "Whether to create a VPN instance"
  default     = true
}

variable "vpn_limit_ingress" {
  description = "Whether to limit the CIDR block of VPN security group inbound rules."
  default     = true
}

variable "vpn_use_spot" {
  description = "Whether to use spot or on-demand EC2 instance"
  default     = false
}

variable "vpn_psk" {
  description = "The IPsec Pre-Shared Key"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "SoftEther VPN admin / database master password"
  type        = string
  sensitive   = true
}

variable "master_username" {
  description = "Database master username"
  default     = "master"
}

variable "database_name" {
  description = "Default database name"
  default     = "main"
}

variable "aurora_create" {
  description = "Whether to create a Aurora cluster"
  default     = true
}

variable "msk_create" {
  description = "Whether to create a MSK cluster"
  default     = true
}

variable "registry_create" {
  description = "Whether to create an Apicurio registry service"
  default     = true
}

locals {
  local_ip_address = "${chomp(data.http.local_ip_address.body)}/32"
  vpn_ingress_cidr = var.vpn_limit_ingress ? local.local_ip_address : "0.0.0.0/0"
  vpn_spot_override = [
    { instance_type : "t3.nano" },
    { instance_type : "t3a.nano" },
  ]
  data_bucket_name = "${var.resource_prefix}-data-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  registry = {
    health_check_path = "/apis/ccompat/v6"
    container_image   = "apicurio/apicurio-registry-sql:2.2.0.Final"
    host_port         = 8080
    container_port    = 8080
    fargate_cpu       = 1024
    fargate_memory    = 2048
    app_count         = 2
    schema_name       = "registry"
    log_group_name    = "/${var.resource_prefix}/ecs"
  }
  msk = {
    version          = "2.8.1"
    instance_size    = "kafka.m5.large"
    ebs_volume_size  = 20
    log_retention_ms = 604800000 # 7 days
  }
}
