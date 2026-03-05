terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Primary region (your server)
provider "aws" {
  region = var.aws_region
}

# Billing alarms must be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

locals {
  # Fixed private IP for MC server so watcher always knows where to proxy
  mc_private_ip = cidrhost(data.aws_subnet.selected.cidr_block, 100)
}
