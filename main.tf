locals {
  cluster = "ganesh"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.61.0"
    }
  }
}

//
// declare AWS cluster
//

// provider
provider "aws" {
  region = "eu-west-2"
}

// vpc
resource "aws_vpc" "net" {
  cidr_block = "10.0.0.0/16"
}

// kms keys
resource "aws_kms_key" "kms-key" {
  description = "KMS key used by Kubernetes"
}

resource "aws_kms_alias" "kms-key-alias" {
  target_key_id = aws_kms_key.kms-key.arn
  name = "alias/${local.cluster}-kms-key"
}

//
// declare GCP cluster
//

//
// declare fleet (in GCP)
//