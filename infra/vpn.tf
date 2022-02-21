module "vpn" {
  source = "terraform-aws-modules/autoscaling/aws"
  count  = var.vpn_create ? 1 : 0

  name = "${var.resource_prefix}-vpn-asg"

  key_name            = var.key_pair_create ? aws_key_pair.key_pair[0].key_name : null
  vpc_zone_identifier = module.vpc.public_subnets
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  image_id                 = data.aws_ami.amazon_linux_2.id
  instance_type            = element([for s in local.vpn_spot_override : s.instance_type], 0)
  security_groups          = [aws_security_group.vpn[0].id]
  iam_instance_profile_arn = aws_iam_instance_profile.vpn[0].arn

  # Launch template
  create_launch_template = true
  update_default_version = true

  user_data_base64 = base64encode(join("\n", [
    "#cloud-config",
    yamlencode({
      # https://cloudinit.readthedocs.io/en/latest/topics/modules.html
      write_files : [
        {
          path : "/opt/vpn/bootstrap.sh",
          content : templatefile("${path.module}/scripts/bootstrap.sh", {
            aws_region     = var.aws_region,
            allocation_id  = aws_eip.vpn[0].allocation_id,
            vpn_psk        = var.vpn_psk,
            admin_password = var.admin_password
          }),
          permissions : "0755",
        }
      ],
      runcmd : [
        ["/opt/vpn/bootstrap.sh"],
      ],
    })
  ]))

  # Mixed instances
  use_mixed_instances_policy = true
  mixed_instances_policy = {
    instances_distribution = {
      on_demand_base_capacity                  = var.vpn_use_spot ? 0 : 1
      on_demand_percentage_above_base_capacity = var.vpn_use_spot ? 0 : 100
      spot_allocation_strategy                 = "capacity-optimized"
    }
    override = local.vpn_spot_override
  }

  tags = {
    "Name" = "${var.resource_prefix}-vpn-asg"
  }
}

resource "aws_eip" "vpn" {
  count = var.vpn_create ? 1 : 0
  tags = {
    "Name" = "${var.resource_prefix}-vpn-eip"
  }
}

resource "aws_security_group" "vpn" {
  count       = var.vpn_create ? 1 : 0
  name        = "${var.resource_prefix}-vpn-sg"
  description = "Allow inbound traffic for SoftEther VPN"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  ingress {
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  ingress {
    from_port   = 1701
    to_port     = 1701
    protocol    = "tcp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  ingress {
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  ingress {
    from_port   = 5555
    to_port     = 5555
    protocol    = "tcp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.vpn_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-vpn-sg"
  }
}

resource "aws_iam_instance_profile" "vpn" {
  count = var.vpn_create ? 1 : 0
  name  = "${var.resource_prefix}-vpn-instance-profile"
  role  = aws_iam_role.vpn[0].name

  tags = {
    "Name" = "${var.resource_prefix}-vpn-instance-profile"
  }
}

resource "aws_iam_role" "vpn" {
  count = var.vpn_create ? 1 : 0
  name  = "${var.resource_prefix}-vpn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${var.resource_prefix}-vpn-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ec2:AssociateAddress",
            "ec2:ModifyInstanceAttribute"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  tags = {
    "Name" = "${var.resource_prefix}-vpn-role"
  }
}
