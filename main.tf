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
resource "aws_vpc" "ganesh-net" {
  cidr_block = "10.0.0.0/16"
}

// kms keys
resource "aws_kms_key" "ganesh-kms-key" {
  description = "KMS key used by Kubernetes"
}

resource "aws_kms_alias" "ganesh-kms-key-alias" {
  target_key_id = aws_kms_key.ganesh-kms-key.arn
  name = "alias/ganesh-kms-key"
}

//
// declare GCP cluster
//

//
// declare fleet (in GCP)
//