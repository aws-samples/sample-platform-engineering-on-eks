// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

data "aws_iam_policy_document" "capabilities_kro_assume_role_policy" {
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

resource "aws_iam_role" "capabilities_kro_role" {
  name               = "${local.env_prefix}-capabilities-kro"
  assume_role_policy = data.aws_iam_policy_document.capabilities_kro_assume_role_policy.json

  tags = local.tags
}

resource "aws_eks_capability" "eks_capabilities_kro" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "kro"
  type                      = "KRO"
  role_arn                  = aws_iam_role.capabilities_kro_role.arn
  delete_propagation_policy = "RETAIN"

  depends_on = [
    aws_iam_role.capabilities_kro_role,
    time_sleep.wait_for_iam_role_propagation
  ]
}

# Grant kro cluster admin permissions to manage K8s resources defined in RGDs
resource "aws_eks_access_policy_association" "kro_access_entry" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.capabilities_kro_role.arn

  access_scope {
    type = "cluster"
  }
}
