// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

locals {
  env_prefix = "${var.resource_prefix}-${var.environment}"
}

# Trust policy allowing ACK controller to assume this role
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "AWS"
      identifiers = [var.ack_controller_role_arn]
    }
  }
}

# IAM policy document from provided statements
data "aws_iam_policy_document" "permissions" {
  count = length(var.iam_policy_statements) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.iam_policy_statements
    content {
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

# IAM role for the namespace
resource "aws_iam_role" "this" {
  name               = "${local.env_prefix}-${var.selector_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = var.tags
}

# Inline policy with provided permissions (only if statements are provided)
resource "aws_iam_role_policy" "this" {
  count = length(var.iam_policy_statements) > 0 ? 1 : 0

  name   = "${local.env_prefix}-${var.selector_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions[0].json
}

# Attach managed policies (if provided)
resource "aws_iam_role_policy_attachment" "managed_policies" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
