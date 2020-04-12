provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  main_cidr               = "10.0.0.0/16"
  availability_zone_count = length(data.aws_availability_zones.available.names)
  subnet_range            = range(0, local.availability_zone_count)
}

resource "random_integer" "single_subnet_number" {
  min = 0
  max = local.availability_zone_count - 1
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

resource "aws_cloud9_environment_ec2" "c9" {
  name                        = "c9"
  description                 = "A c9 environment for managing this project."
  instance_type               = "t3.nano"
  automatic_stop_time_minutes = "30"

  subnet_id = module.vpc.public_subnets[
    random_integer.single_subnet_number.result
  ]
}
