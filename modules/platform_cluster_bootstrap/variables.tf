// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_arn" {
  description = "EKS cluster ARN"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform Repository URL"
  type        = string
}

variable "platform_repo_path" {
  description = "Platform Repository Path"
  type        = string
  default     = ""
}

variable "platform_repo_revision" {
  description = "Platform Repository Revision"
  type        = string
  default     = "main"
}

variable "workload_repo_url" {
  description = "Workload Repository URL"
  type        = string
}

variable "workload_repo_path" {
  description = "Workload Repository Path"
  type        = string
  default     = ""
}

variable "workload_repo_revision" {
  description = "Workload Repository Revision"
  type        = string
  default     = "main"
}
