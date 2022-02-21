module "aurora" {
  source         = "terraform-aws-modules/rds-aurora/aws"
  create_cluster = var.aurora_create

  name                       = "${var.resource_prefix}-db-cluster"
  engine                     = "aurora-postgresql"
  engine_version             = "13"
  auto_minor_version_upgrade = false

  instances = {
    1 = {
      instance_class = "db.t3.medium"
    }
  }

  vpc_id                 = module.vpc.vpc_id
  db_subnet_group_name   = var.aurora_create ? aws_db_subnet_group.aurora[0].id : ""
  create_db_subnet_group = false
  create_security_group  = true
  vpc_security_group_ids = compact([join("", aws_security_group.db_access.*.id)])

  iam_database_authentication_enabled = false
  create_random_password              = false
  master_username                     = var.master_username
  master_password                     = var.admin_password
  database_name                       = var.database_name

  apply_immediately   = true
  skip_final_snapshot = true

  db_cluster_parameter_group_name = var.aurora_create ? aws_rds_cluster_parameter_group.aurora[0].id : null
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "${var.resource_prefix}-db-cluster"
  }
}

resource "aws_db_subnet_group" "aurora" {
  name       = "${var.resource_prefix}-db-subnet-group"
  count      = var.aurora_create ? 1 : 0
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "${var.resource_prefix}-db-subnet-group"
  }
}

resource "aws_rds_cluster_parameter_group" "aurora" {
  name  = "${var.resource_prefix}-aurora-postgres13-cluster-parameter-group"
  count = var.aurora_create ? 1 : 0

  family = "aurora-postgresql13"

  # for Debezium pgoutput plugin
  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.resource_prefix}-aurora-postgres13-cluster-parameter-group"
  }
}

resource "aws_security_group" "db_access" {
  name  = "${var.resource_prefix}-db-security-group"
  count = var.aurora_create ? 1 : 0

  vpc_id = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_vpn_inbound" {
  count                    = (var.aurora_create && var.vpn_create) ? 1 : 0
  type                     = "ingress"
  description              = "VPN access"
  security_group_id        = aws_security_group.db_access[0].id
  protocol                 = "tcp"
  from_port                = "5432"
  to_port                  = "5432"
  source_security_group_id = aws_security_group.vpn[0].id
}

resource "aws_security_group_rule" "db_registry_inbound" {
  count                    = (var.aurora_create && var.registry_create) ? 1 : 0
  type                     = "ingress"
  description              = "Registry access"
  security_group_id        = aws_security_group.db_access[0].id
  protocol                 = "tcp"
  from_port                = "5432"
  to_port                  = "5432"
  source_security_group_id = aws_security_group.registry_task_sg[0].id
}

resource "aws_security_group_rule" "db_msk_inbound" {
  count                    = (var.aurora_create && var.msk_create) ? 1 : 0
  type                     = "ingress"
  description              = "MSK access"
  security_group_id        = aws_security_group.db_access[0].id
  protocol                 = "tcp"
  from_port                = "5432"
  to_port                  = "5432"
  source_security_group_id = aws_security_group.msk[0].id
}
