// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0.0"
    }
  }
}

locals {
  env_prefix = "${var.resource_prefix}-${var.environment}"

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Prefix      = var.resource_prefix
    Environment = var.environment
  }
}

output "argo_cd_capability_iam_role_name" {
  value = aws_iam_role.capabilities_argo_cd_role.name
}

output "cluster_name" {
  value = module.eks.cluster_name
}
