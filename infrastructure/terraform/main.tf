terraform {
  backend "s3" {
    encrypt = true
    bucket  = "os-manager-project-terraform-state"
    key     = "tfstate"
    region  = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

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

# Project infrastructure
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

# Tool permissions
resource "aws_iam_group" "tools" {
  name = "tools"
  path = "/tools/"
}

resource "aws_iam_group_policy_attachment" "tools" {
  group = aws_iam_group.tools.name

  policy_arn = "arn:aws:iam::${
    data.aws_caller_identity.current.account_id
  }:policy/tools/ContinuousIntegrationPolicy"
}


# CircleCI
resource "aws_iam_user" "circleci" {
  name = "circleci"
  path = "/continuous-integration/"
}

resource "aws_iam_access_key" "circleci" {
  user = aws_iam_user.circleci.name
}

# Tool permission associations
resource "aws_iam_group_membership" "tools" {
  name  = "tool-group-membership"
  group = aws_iam_group.tools.name

  users = [
    aws_iam_user.circleci.name
  ]
}

# Terraform infrastructure
resource "aws_s3_bucket" "log_bucket" {
  bucket = "os-management-project-s3-logs"
  acl    = "log-delivery-write"

  lifecycle_rule {
    id      = "log"
    enabled = true

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "os-manager-project-terraform-state"
  acl    = "private"

  versioning {
    enabled = false
  }

  logging {
    target_bucket = aws_s3_bucket.log_bucket.id
    target_prefix = "terraform_state/"
  }

  lifecycle_rule {
    id      = "state"
    enabled = true

    transition {
      days          = 30
      storage_class = "ONEZONE_IA"
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

output "circleci_access_key" {
  value       = aws_iam_access_key.circleci.id
  description = "The access key used by CircleCI. Secret"
  sensitive   = true
}

output "circleci_secret_key" {
  value       = aws_iam_access_key.circleci.secret
  description = "The SECRET key used by CircleCI. Even more secret."
  sensitive   = true
}