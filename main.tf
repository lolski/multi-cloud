locals {
  cluster = "ganesh"
  gcp_project_number = "225200396825" // vaticle-typedb-cloud-dev
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

// roles
data "aws_iam_policy_document" "policy-multi-cloud-api" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["accounts.google.com"]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "accounts.google.com:sub"
      values = [
        "service-${local.gcp_project_number}@gcp-sa-gkemulticloud.iam.gserviceaccount.com"
      ]
    }
  }
}

resource "aws_iam_role" "role-multi-cloud-api" {
  name = "${local.cluster}-role-multi-cloud-api"
  assume_role_policy = data.aws_iam_policy_document.policy-multi-cloud-api.json
}

data "aws_iam_policy_document" "policy-control-plane" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role-control-plane" {
  name = "${local.cluster}-role-control-plane"
  assume_role_policy = data.aws_iam_policy_document.policy-control-plane.json
}

data "aws_iam_policy_document" "policy-node-pool" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role-node-pool" {
  name = "${local.cluster}-role-node-pool"
  assume_role_policy = data.aws_iam_policy_document.policy-node-pool.json
}

//
// declare GCP cluster
//

//
// declare fleet (in GCP)
//