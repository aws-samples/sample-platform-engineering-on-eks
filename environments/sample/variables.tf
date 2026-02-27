// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


variable "aws_profile" {
  description = "AWS profile to manage the AWS account where the env are created"
  type        = string
}
variable "aws_region" {
  description = "AWS region where the env are created"
  type        = string
}

variable "resource_prefix" {
  description = "Resource name prefix for avoiding to conflict names on an AWS account"
  type        = string
  default     = "ex-idp"
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
  description = "Network Flow Monitor Scope Arn for Container Network Observability"
  default     = null
  type        = string
}
