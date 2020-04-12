provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  main_cidr    = "10.0.0.0/16"
  subnet_range = range(0, length(data.aws_availability_zones.available.names))
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "default-vpc"
  cidr = local.main_cidr

  azs = data.aws_availability_zones.available.names
  private_subnets = [
    for index in local.subnet_range :
    cidrsubnet(local.main_cidr, 4, index)
  ]

  public_subnets = [
    for index in local.subnet_range :
    cidrsubnet(local.main_cidr, 4, index + 6)
  ]
}
