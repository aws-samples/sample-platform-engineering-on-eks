// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


locals {
  environment = "dev"
  env_prefix  = "${var.resource_prefix}-${local.environment}"

  platform_repo_name = "${local.env_prefix}-platform"
  platform_repo_url  = "https://git-codecommit.${var.aws_region}.amazonaws.com/v1/repos/${local.platform_repo_name}"
  workload_repo_name = "${local.env_prefix}-workload"
  workload_repo_url  = "https://git-codecommit.${var.aws_region}.amazonaws.com/v1/repos/${local.workload_repo_name}"

}

module "cluster_development" {
  source                         = "../../modules/platform_cluster"
  aws_region                     = var.aws_region
  environment                    = "dev"
  argo_cd_idc_instance_arn       = var.argo_cd_idc_instance_arn
  argo_cd_idc_region             = var.argo_cd_idc_region
  argo_cd_idc_groups             = var.argo_cd_idc_groups
  network_flow_monitor_scope_arn = var.network_flow_monitor_scope_arn
}

module "platform_cluster_bootstrap" {
  source = "../../modules/platform_cluster_bootstrap"

  cluster_name      = module.cluster_development.cluster_name
  cluster_arn       = module.cluster_development.cluster_arn
  environment       = local.environment
  platform_repo_url = local.platform_repo_url
  workload_repo_url = local.workload_repo_url
}
