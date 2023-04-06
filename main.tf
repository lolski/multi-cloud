//////////////////////////////
// config
//////////////////////////////

locals {
  cluster = "ganesh"
  gcp-project = "vaticle-typedb-cloud-dev"
  gcp-project-number = "225200396825"
}

//////////////////////////////
// terraform providers
//////////////////////////////

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.61.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "4.60.1"
    }
  }
}

//////////////////////////////
// declare AWS cluster
//////////////////////////////

// provider
provider "aws" {
  region = "eu-west-2"
}


// vpc
resource "aws_vpc" "net" {
  cidr_block = "10.0.0.0/16"
}


// subnets
resource "aws_subnet" "subnet-control-plane" {
  vpc_id            = aws_vpc.net.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
}


// kms keys
resource "aws_kms_key" "kms-key" {
}

resource "aws_kms_alias" "kms-key-alias" {
  target_key_id = aws_kms_key.kms-key.arn
  name = "alias/${local.cluster}-kms-key"
}


// roles
data "aws_iam_policy_document" "policy-assume-role-gcp" {
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
        "service-${local.gcp-project-number}@gcp-sa-gkemulticloud.iam.gserviceaccount.com"
      ]
    }
  }
}

resource "aws_iam_role" "role-multicloud-api" {
  name = "${local.cluster}-role-multicloud-api"
  assume_role_policy = data.aws_iam_policy_document.policy-assume-role-gcp.json
}

data "aws_iam_policy_document" "policy-document-permissions-multicloud-api" {
  statement {
    effect = "Allow"
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:DeleteTags",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateNetworkInterface",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteVolume",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:GetConsoleOutput",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RemoveTags",
      "iam:AWSServiceName",
      "iam:CreateServiceLinkedRole",
      "iam:PassRole",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:DescribeKey",
    ]
    resources = [
      "arn:aws:kms:*:*:key/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
    ]
    resources = [aws_kms_key.kms-key.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
    ]
    resources = [aws_kms_key.kms-key.arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "kms:GenerateDataKeyWithoutPlaintext",
    ]
    resources = [aws_kms_key.kms-key.arn]
  }
}

resource "aws_iam_policy" "policy-permissions-multicloud-api" {
  name   = "${local.cluster}-policy-permissions-multicloud-api"
  path   = "/"
  policy = data.aws_iam_policy_document.policy-document-permissions-multicloud-api.json
}

resource "aws_iam_role_policy_attachment" "role-policy-attachment-multicloud-api" {
  role       = aws_iam_role.role-multicloud-api.name
  policy_arn = aws_iam_policy.policy-permissions-multicloud-api.arn
}

data "aws_iam_policy_document" "policy-assume-role-ec2" {
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
  assume_role_policy = data.aws_iam_policy_document.policy-assume-role-ec2.json
}

resource "aws_iam_instance_profile" "instance-profile-control-plane" {
  name = "${local.cluster}-instance-profile-control-plane"
  role = aws_iam_role.role-control-plane.id
}

resource "aws_iam_role" "role-node-pool" {
  name = "${local.cluster}-role-node-pool"
  assume_role_policy = data.aws_iam_policy_document.policy-assume-role-ec2.json
}


// cluster
resource "google_container_aws_cluster" "kubernetes-cluster" {
  name = "${local.cluster}-kubernetes"
  project = local.gcp-project
  aws_region = "eu-west-2"
  location = "europe-west2"

  authorization {
    admin_users {
      username = "ganesh@vaticle.com"
    }
  }
  control_plane {
    iam_instance_profile = aws_iam_instance_profile.instance-profile-control-plane.name
    subnet_ids           = [aws_subnet.subnet-control-plane.id]
    version              = "1.24.10-gke.1200"
    tags = {
      "Name" : "${local.cluster}-kubernetes-cluster-control-plane"
    }

    aws_services_authentication {
      role_arn = aws_iam_role.role-multicloud-api.arn
    }
    config_encryption {
      kms_key_arn = aws_kms_key.kms-key.arn
    }
    database_encryption {
      kms_key_arn = aws_kms_key.kms-key.arn
    }
  }
  networking {
    pod_address_cidr_blocks     = ["10.2.0.0/16"]
    service_address_cidr_blocks = ["10.1.0.0/16"]
    vpc_id                      = aws_vpc.net.id
  }
  fleet {
    project = "projects/${local.gcp-project-number}"
  }
  timeouts {
    create = "25m"
    update = "25m"
    delete = "25m"
  }
}