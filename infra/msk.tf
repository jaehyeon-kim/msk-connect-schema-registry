resource "aws_msk_cluster" "msk_data_cluster" {
  count = var.msk_create ? 1 : 0

  cluster_name           = "${var.resource_prefix}-msk-cluster"
  kafka_version          = local.msk.version
  number_of_broker_nodes = length(module.vpc.private_subnets)
  configuration_info {
    arn      = aws_msk_configuration.msk_config[0].arn
    revision = aws_msk_configuration.msk_config[0].latest_revision
  }

  broker_node_group_info {
    client_subnets  = module.vpc.private_subnets
    ebs_volume_size = local.msk.ebs_volume_size
    instance_type   = local.msk.instance_size
    security_groups = [aws_security_group.msk[0].id]
  }

  client_authentication {
    sasl {
      iam = true
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = true
        log_group = aws_cloudwatch_log_group.msk_cluster_lg[0].name
      }
      s3 {
        enabled = true
        bucket  = aws_s3_bucket.data_bucket.id
        prefix  = "logs/msk/cluster-"
      }
    }
  }

  depends_on = [aws_msk_configuration.msk_config]
}

# MSK Configuration
resource "aws_msk_configuration" "msk_config" {
  count = var.msk_create ? 1 : 0
  name  = "${var.resource_prefix}-msk-configuration"

  kafka_versions = [local.msk.version]

  server_properties = <<PROPERTIES
    auto.create.topics.enable = true
    delete.topic.enable = true
    log.retention.ms = ${local.msk.log_retention_ms}
  PROPERTIES
}

resource "aws_security_group" "msk" {
  count  = var.msk_create ? 1 : 0
  name   = "${var.resource_prefix}-msk-sg"
  vpc_id = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.resource_prefix}-msk-sg"
  }
}

resource "aws_security_group_rule" "msk_self_inbound" {
  count                    = var.msk_create ? 1 : 0
  type                     = "ingress"
  description              = "Allow ingress from itself - required for MSK Connect"
  security_group_id        = aws_security_group.msk[0].id
  protocol                 = "-1"
  from_port                = "0"
  to_port                  = "0"
  source_security_group_id = aws_security_group.msk[0].id
}

resource "aws_security_group_rule" "msk_all_outbound" {
  count             = var.msk_create ? 1 : 0
  type              = "egress"
  description       = "Allow outbound all"
  security_group_id = aws_security_group.msk[0].id
  protocol          = "-1"
  from_port         = "0"
  to_port           = "0"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "msk_vpn_inbound" {
  count                    = (var.msk_create && var.vpn_create) ? 1 : 0
  type                     = "ingress"
  description              = "VPN Access"
  security_group_id        = aws_security_group.msk[0].id
  protocol                 = "tcp"
  from_port                = "9098"
  to_port                  = "9098"
  source_security_group_id = aws_security_group.vpn[0].id
}

resource "aws_cloudwatch_log_group" "msk_cluster_lg" {
  count = var.msk_create ? 1 : 0
  name  = "/${var.resource_prefix}/msk/cluster"

  retention_in_days = 3

  tags = {
    Name = "/${var.resource_prefix}/msk/cluster"
  }
}

resource "aws_iam_role" "msk_connect_role" {
  count = var.msk_create ? 1 : 0
  name  = "${var.resource_prefix}-msk-connect-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "KafkaConnectAssumeRole"
        Principal = {
          Service = "kafkaconnect.amazonaws.com"
        }
      }
    ]
  })

  inline_policy {
    name = "KafkaConnectPolicy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid = "LoggingPermission"
          Action = [
            "logs:CreateLogStream",
            "logs:CreateLogGroup",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = "${aws_cloudwatch_log_group.msk_cluster_lg[0].arn}*"
        },
        {
          Sid = "PermissionOnCluster"
          Action = [
            "kafka-cluster:Connect",
            "kafka-cluster:AlterCluster",
            "kafka-cluster:DescribeCluster"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.resource_prefix}-msk-cluster/*"
        },
        {
          Sid = "PermissionOnTopics"
          Action = [
            "kafka-cluster:*Topic*",
            "kafka-cluster:WriteData",
            "kafka-cluster:ReadData"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:topic/${var.resource_prefix}-msk-cluster/*"
        },
        {
          Sid = "PermissionOnGroups"
          Action = [
            "kafka-cluster:AlterGroup",
            "kafka-cluster:DescribeGroup"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:kafka:${var.aws_region}:${data.aws_caller_identity.current.account_id}:group/${var.resource_prefix}-msk-cluster/*"
        },
        {
          Sid = "PermissionOnDataBucket"
          Action = [
            "s3:ListBucket",
            "s3:*Object"
          ]
          Effect = "Allow"
          Resource = [
            "arn:aws:s3:::${local.data_bucket_name}",
            "arn:aws:s3:::${local.data_bucket_name}/*"
          ]
        },
      ]
    })
  }
}
