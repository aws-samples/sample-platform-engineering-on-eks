// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


resource "aws_codecommit_repository" "platform" {
  repository_name = local.platform_repo_name
  description     = "The repository for storing platform settings"
}

resource "aws_codecommit_repository" "workload" {
  repository_name = local.workload_repo_name
  description     = "The repository for storing platform settings"
}

data "aws_iam_policy_document" "argo_cd_capability_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "codecommit:GitPull"
    ]
    resources = [
      aws_codecommit_repository.platform.arn,
      aws_codecommit_repository.workload.arn,
    ]
  }
}

resource "aws_iam_policy" "argo_cd_capability_role_policy" {
  policy = data.aws_iam_policy_document.argo_cd_capability_role_policy.json
}

resource "aws_iam_role_policy_attachment" "argo_cd_capability_role_attachment" {
  role       = module.cluster_development.argo_cd_capability_iam_role_name
  policy_arn = aws_iam_policy.argo_cd_capability_role_policy.arn
}
