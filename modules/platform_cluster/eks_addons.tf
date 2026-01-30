// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


## CloudWatch Observability Addons IAM Permissions

data "aws_iam_policy_document" "cloudwatch_observability_addon_assume_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_observability_addon" {
  name               = "${local.env_prefix}-cw-addon"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_observability_addon_assume_role_policy.json

  tags = local.tags
}

data "aws_iam_policy" "cloudwatch_observability_addon" {
  name = "CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_observability_addon" {
  role       = aws_iam_role.cloudwatch_observability_addon.name
  policy_arn = data.aws_iam_policy.cloudwatch_observability_addon.arn
}
