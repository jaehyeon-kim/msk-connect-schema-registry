module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${var.resource_prefix}-vpc"
  cidr = "10.${var.class_b}.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.${var.class_b}.0.0/19", "10.${var.class_b}.32.0/19"]
  public_subnets  = ["10.${var.class_b}.64.0/19", "10.${var.class_b}.96.0/19"]

  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
}
