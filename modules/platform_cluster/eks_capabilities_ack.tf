// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_iam_policy_document" "capabilities_ack_assume_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]

    principals {
      type        = "Service"
      identifiers = ["capabilities.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "capabilities_ack_role" {
  name               = "${local.env_prefix}-capabilities-ack"
  assume_role_policy = data.aws_iam_policy_document.capabilities_ack_assume_role_policy.json

  tags = local.tags
}

resource "time_sleep" "wait_for_iam_role_propagation" {
  depends_on = [aws_iam_role.capabilities_ack_role]

  create_duration = "10s"
}

resource "aws_eks_capability" "eks_capabilities_ack" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "ack"
  type                      = "ACK"
  role_arn                  = aws_iam_role.capabilities_ack_role.arn
  delete_propagation_policy = "RETAIN"

  depends_on = [
    aws_iam_role.capabilities_ack_role,
    time_sleep.wait_for_iam_role_propagation
  ]
}
