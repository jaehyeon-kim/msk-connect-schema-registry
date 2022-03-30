resource "tls_private_key" "pk" {
  count     = var.key_pair_create ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  count      = var.key_pair_create ? 1 : 0
  key_name   = "${var.resource_prefix}-key"
  public_key = tls_private_key.pk[0].public_key_openssh
}

resource "local_sensitive_file" "pem_file" {
  count           = var.key_pair_create ? 1 : 0
  filename        = pathexpand("${path.module}/key-pair/${var.resource_prefix}-key.pem")
  file_permission = "0400"
  content         = tls_private_key.pk[0].private_key_pem
}
