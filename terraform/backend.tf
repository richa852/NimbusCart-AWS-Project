# Remote state lives in S3 with a DynamoDB lock table.
#
# This file deliberately does NOT create the S3 bucket or the DynamoDB
# table it points to. A backend can't read remote state from
# infrastructure that doesn't exist yet, so the bucket and lock table
# are bootstrapped once, by hand or via a separate bootstrap stack,
# before `terraform init` is ever run against this config.

terraform {
  backend "s3" {
    bucket         = "nimbuscart-tfstate-<your-unique-suffix>"
    key            = "nimbuscart/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "nimbuscart-tf-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
