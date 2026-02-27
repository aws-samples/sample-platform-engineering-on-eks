// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


## Kubernetes on EKS ##

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  // checkov:skip=CKV_TF_1:The module is not from a git source.
  version = "~> 21.0"

  name                   = "${local.env_prefix}-cluster"
  kubernetes_version     = var.kubernetes_version
  endpoint_public_access = true
  create_kms_key         = false
  encryption_config      = null
  authentication_mode    = "API"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  # Auto Mode
  compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  # EKS Addons
  addons = merge(
    var.network_flow_monitor_scope_arn != "" ? {
      aws-network-flow-monitoring-agent = {
        pod_identity_association = [
          {
            role_arn        = aws_iam_role.nfm_addon[0].arn
            service_account = "aws-network-flow-monitor-agent-service-account"
          }
        ]
      }
    } : {},
    {
      amazon-cloudwatch-observability = {
        pod_identity_association = [
          {
            role_arn        = aws_iam_role.cloudwatch_observability_addon.arn
            service_account = "cloudwatch-agent"
          }
        ]
        configuration_values = jsonencode({
          manager = {
            applicationSignals = {
              autoMonitor = {
                monitorAllServices = true
                restartPods        = true
                exclude = {
                  java   = { namespaces = ["argocd", "amazon-guardduty"] }
                  python = { namespaces = ["argocd", "amazon-guardduty"] }
                  dotnet = { namespaces = ["argocd", "amazon-guardduty"] }
                  nodejs = { namespaces = ["argocd", "amazon-guardduty"] }
                }
              }
            }
          }
        })
      }
    }
  )
  tags = local.tags
}
