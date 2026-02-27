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

## Network Observability IAM Permissions

data "aws_iam_policy_document" "nfm_addon_assume_role_policy" {
  count = var.network_flow_monitor_scope_arn != null ? 1 : 0

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

resource "aws_iam_role" "nfm_addon" {
  count = var.network_flow_monitor_scope_arn != null ? 1 : 0

  name               = "${local.env_prefix}-nfm-addon"
  assume_role_policy = data.aws_iam_policy_document.nfm_addon_assume_role_policy[0].json

  tags = local.tags
}

data "aws_iam_policy" "nfm_addon" {
  count = var.network_flow_monitor_scope_arn != null ? 1 : 0

  name = "CloudWatchNetworkFlowMonitorAgentPublishPolicy"
}

resource "aws_iam_role_policy_attachment" "nfm_addon" {
  count = var.network_flow_monitor_scope_arn != null ? 1 : 0

  role       = aws_iam_role.nfm_addon[0].name
  policy_arn = data.aws_iam_policy.nfm_addon[0].arn
}

resource "aws_networkflowmonitor_monitor" "platform_cluster_monitor" {
  count = var.network_flow_monitor_scope_arn != null ? 1 : 0

  monitor_name = "${local.env_prefix}-monitor"
  scope_arn    = var.network_flow_monitor_scope_arn

  local_resource {
    type       = "AWS::EKS::Cluster"
    identifier = module.eks.cluster_arn
  }

  remote_resource {
    type       = "AWS::Region"
    identifier = var.aws_region
  }

  tags = local.tags
}
