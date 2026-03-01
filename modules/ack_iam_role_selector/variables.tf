// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

variable "resource_prefix" {
  description = "Prefix for resource names (e.g., 'ex-idp')"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., 'dev', 'prod')"
  type        = string
}

variable "selector_name" {
  description = "Name of the IAM Role Selector resource"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where the IAM Role Selector will be created"
  type        = string
}

variable "iam_policy_statements" {
  description = "List of IAM policy statements to attach to the role as inline policy"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "managed_policy_arns" {
  description = "List of AWS managed or customer managed policy ARNs to attach to the role"
  type        = list(string)
  default     = []
}

variable "ack_controller_role_arn" {
  description = "ARN of the ACK controller role that will assume this role"
  type        = string
}

variable "namespace_selector_names" {
  description = "List of namespace names to match. Empty list with label_selector matches by labels only"
  type        = list(string)
  default     = []
}

variable "namespace_selector_labels" {
  description = "Map of labels to match namespaces"
  type        = map(string)
  default     = {}
}

variable "resource_type_selectors" {
  description = "List of resource types to scope the role to (optional)"
  type = list(object({
    group   = string
    version = string
    kind    = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to AWS resources"
  type        = map(string)
  default     = {}
}
