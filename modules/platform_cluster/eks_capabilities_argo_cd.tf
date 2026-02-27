// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


data "aws_iam_policy_document" "capabilities_argo_cd_assume_role_policy" {
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

resource "aws_iam_role" "capabilities_argo_cd_role" {
  name               = "${local.env_prefix}-capabilities-argo-cd"
  assume_role_policy = data.aws_iam_policy_document.capabilities_argo_cd_assume_role_policy.json

  tags = local.tags
}

resource "aws_eks_capability" "eks_capabilities" {
  cluster_name              = module.eks.cluster_name
  capability_name           = "argocd"
  type                      = "ARGOCD"
  role_arn                  = aws_iam_role.capabilities_argo_cd_role.arn
  delete_propagation_policy = "RETAIN"

  configuration {
    argo_cd {
      aws_idc {
        idc_instance_arn = var.argo_cd_idc_instance_arn
        idc_region       = var.argo_cd_idc_region
      }
      dynamic "rbac_role_mapping" {
        for_each = var.argo_cd_idc_groups
        content {
          identity {
            id   = rbac_role_mapping.key
            type = "SSO_GROUP"
          }
          role = rbac_role_mapping.value
        }
      }
    }
  }
  tags = local.tags
}

## Register Cluster
resource "kubernetes_secret_v1" "platform_cluster" {
  metadata {
    name      = module.eks.cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      cluster_name                     = module.eks.cluster_name
      environment                      = var.environment
      platform_cluster                 = true
      workload_cluster                 = true
      enable_argo_rollouts             = true
    }
    annotations = merge(
      {
        platform_repo_url      = var.platform_repo_url
        platform_repo_path     = var.platform_repo_path
        platform_repo_revision = var.platform_repo_revision
      },
      {
        workload_repo_url      = var.workload_repo_url
        workload_repo_path     = var.workload_repo_path
        workload_repo_revision = var.workload_repo_revision
      },
    )
  }

  data = {
    name    = module.eks.cluster_name
    server  = module.eks.cluster_arn
    project = "default"
  }
}

resource "aws_eks_access_policy_association" "argo_cd_access_entry" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.capabilities_argo_cd_role.arn

  access_scope {
    type = "cluster"
  }
}
