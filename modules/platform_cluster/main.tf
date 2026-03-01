// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
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

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "ack_capability_role_arn" {
  description = "ARN of the ACK capability IAM role"
  value       = aws_iam_role.capabilities_ack_role.arn
}
