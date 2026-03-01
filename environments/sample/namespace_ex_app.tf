// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

module "ack_iam_role_selector_ex_app_s3" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix          = var.resource_prefix
  environment              = local.environment
  selector_name            = "ex-app-s3"
  namespace                = "ex-app"
  ack_controller_role_arn  = module.cluster_development.ack_capability_role_arn
  namespace_selector_names = ["ex-app"]

  # S3 permissions: full access to specific buckets only
  iam_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:*",
        "s3-object-lambda:*"
      ]
      resources = [
        "arn:aws:s3:::${local.env_prefix}-ex-app-*",
        "arn:aws:s3:::${local.env_prefix}-ex-app-*/*"
      ]
    },
    {
      effect = "Allow"
      actions = [
        "s3:ListAllMyBuckets"
      ]
      resources = [
        "*"
      ]
    }
  ]
}
