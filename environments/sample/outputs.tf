// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


output "platform_repo_url" {
  description = "CodeCommit Platform Repository URL"
  value       = local.platform_repo_url
}

output "workload_repo_url" {
  description = "CodeCommit Workload Repository URL"
  value       = local.workload_repo_url
}

output "cluster_name" {
  description = "EKS Cluster Name"
  value       = module.cluster_development.cluster_name
}

output "argo_cd_url_command" {
  description = "Command to get Argo CD URL"
  value       = "aws eks describe-capability --cluster-name ${module.cluster_development.cluster_name} --capability-name argocd --query 'capability.configuration.argoCd.serverUrl' --output text"
}
