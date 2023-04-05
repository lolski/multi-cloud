terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.61.0"
    }
  }
}

// declare AWS cluster
provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "ganesh-net" {
  cidr_block = "10.0.0.0/16"
}

// declare GCP cluster

// declare fleet (in GCP)
