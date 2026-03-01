// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


variable "aws_region" {
  description = "AWS region where the env are created"
  type        = string
}

variable "resource_prefix" {
  description = "Resource name prefix for avoiding to conflict names on an AWS account"
  type        = string
  default     = "ex-idp"
}

variable "vpc_cidr" {
  description = "VPC CIDR of the platform cluster"
  type        = string
  default     = "10.72.0.0/16"
}

variable "environment" {
  description = "Environment Name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "argo_cd_idc_region" {
  description = "Identity Center region for ArgoCD"
  type        = string
}

variable "argo_cd_idc_instance_arn" {
  description = "Identity Center Instance ARN for ArgoCD"
  type        = string
}

variable "argo_cd_idc_groups" {
  description = "Admin Groups for ArgoCD"
  type        = map(string)
}

variable "network_flow_monitor_scope_arn" {
  description = "ARN of the Network Flow Monitor scope. If not set, NFM resources will not be created."
  type        = string
  default     = null
}
