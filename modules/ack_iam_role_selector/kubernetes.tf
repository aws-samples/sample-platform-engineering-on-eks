// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

# IAM Role Selector CRD resource
resource "kubernetes_manifest" "iam_role_selector" {
  manifest = {
    apiVersion = "services.k8s.aws/v1alpha1"
    kind       = "IAMRoleSelector"
    metadata = {
      name = var.selector_name
    }
    spec = merge(
      {
        arn = aws_iam_role.this.arn
        namespaceSelector = merge(
          {
            names = var.namespace_selector_names
          },
          length(var.namespace_selector_labels) > 0 ? {
            labelSelector = {
              matchLabels = var.namespace_selector_labels
            }
          } : {}
        )
      },
      length(var.resource_type_selectors) > 0 ? {
        resourceTypeSelector = [
          for selector in var.resource_type_selectors : {
            group   = selector.group
            version = selector.version
            kind    = selector.kind
          }
        ]
      } : {}
    )
  }

  depends_on = [
    aws_iam_role.this,
    aws_iam_role_policy.this,
    aws_iam_role_policy_attachment.managed_policies
  ]
}
