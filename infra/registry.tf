resource "aws_ecs_cluster" "registry_ecs_cluster" {
  name  = "${var.resource_prefix}-registry-ecs-cluster"
  count = var.registry_create ? 1 : 0

  tags = {
    Name = "${var.resource_prefix}-registry-ecs-cluster"
  }
}

data "template_file" "registry_container_defs" {
  count = var.registry_create ? 1 : 0

  template = file("${path.module}/templates/registry-container-defs.tpl")

  vars = {
    container_image      = local.registry.container_image
    container_port       = local.registry.container_port
    host_port            = local.registry.host_port
    fargate_cpu          = local.registry.fargate_cpu
    fargate_memory       = local.registry.fargate_memory
    log_group_name       = local.registry.log_group_name
    aws_region           = var.aws_region
    app_env              = var.environment
    data_source_url      = "jdbc:postgresql://${module.aurora.cluster_endpoint}/${var.database_name}?currentSchema=${local.registry.schema_name}"
    data_source_username = var.master_username
    data_source_password = var.admin_password
  }
}

resource "aws_ecs_task_definition" "registry_task_def" {
  count = var.registry_create ? 1 : 0

  family                   = "${var.resource_prefix}-registry-task-def"
  execution_role_arn       = aws_iam_role.registry_task_exec_role[0].arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.registry.fargate_cpu
  memory                   = local.registry.fargate_memory
  container_definitions    = data.template_file.registry_container_defs[0].rendered

  tags = {
    Name = "${var.resource_prefix}-registry-task-def"
  }
}

resource "aws_ecs_service" "registry_service" {
  count = var.registry_create ? 1 : 0

  name            = "${var.resource_prefix}-registry-service"
  cluster         = aws_ecs_cluster.registry_ecs_cluster[0].id
  task_definition = aws_ecs_task_definition.registry_task_def[0].arn
  desired_count   = local.registry.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.registry_task_sg[0].id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.registry_lb_tg[0].id
    container_name   = "registry"
    container_port   = local.registry.container_port
  }

  tags = {
    Name = "${var.resource_prefix}-registry-service"
  }

  depends_on = [aws_lb_listener.registry_lb_listener[0]]
}

resource "aws_iam_role" "registry_task_exec_role" {
  count = var.registry_create ? 1 : 0
  name  = "${var.resource_prefix}-registry-task-exec-role"

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    "Name" = "${var.resource_prefix}-registry-task-exec-role"
  }
}

resource "aws_lb" "registry_lb" {
  count = var.registry_create ? 1 : 0

  name               = "${var.resource_prefix}-registry-lb"
  internal           = true
  load_balancer_type = "application"
  subnets            = module.vpc.private_subnets
  security_groups    = [aws_security_group.registry_lb_sg[0].id]

  tags = {
    Name = "${var.resource_prefix}-registry-lb"
  }
}

resource "aws_lb_target_group" "registry_lb_tg" {
  count = var.registry_create ? 1 : 0

  name        = "${var.resource_prefix}-registry-lb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "10"
    path                = local.registry.health_check_path
    unhealthy_threshold = "3"
  }

  tags = {
    Name = "${var.resource_prefix}-registry-lb-tg"
  }
}

resource "aws_lb_listener" "registry_lb_listener" {
  count = var.registry_create ? 1 : 0

  load_balancer_arn = aws_lb.registry_lb[0].id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.registry_lb_tg[0].id
  }
}

resource "aws_security_group" "registry_lb_sg" {
  count       = var.registry_create ? 1 : 0
  name        = "${var.resource_prefix}-registry-lb-sg"
  description = "Allow inbound traffic from selected source security groups"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = compact([join("", aws_security_group.vpn.*.id), join("", aws_security_group.msk.*.id)])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-registry-lb-sg"
  }
}

resource "aws_security_group" "registry_task_sg" {
  count       = (var.registry_create || var.vpn_create) ? 1 : 0
  name        = "${var.resource_prefix}-registry-task-sg"
  description = "Allow inbound traffic from only LB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = compact([join("", aws_security_group.vpn.*.id), join("", aws_security_group.registry_lb_sg.*.id)])
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-registry-task-sg"
  }
}

resource "aws_cloudwatch_log_group" "registry_ecs_lg" {
  count = var.registry_create ? 1 : 0
  name  = local.registry.log_group_name

  tags = {
    Name = local.registry.log_group_name
  }
}
