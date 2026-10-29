terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
}

module "fleet" {
  source      = "../modules/ec2-fleet"
  instances   = var.instances
  environment = var.environment
  owner       = var.owner
}
