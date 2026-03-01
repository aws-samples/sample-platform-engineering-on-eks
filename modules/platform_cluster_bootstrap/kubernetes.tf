// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0

## Register Cluster
resource "kubernetes_secret_v1" "platform_cluster" {
  metadata {
    name      = var.cluster_name
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      cluster_name                     = var.cluster_name
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
    name    = var.cluster_name
    server  = var.cluster_arn
    project = "default"
  }
}

## ArgoCD Bootstrap ApplicationSet
resource "kubernetes_manifest" "bootstrap" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "bootstrap"
      namespace = "argocd"
    }
    spec = {
      goTemplate = true
      syncPolicy = {
        preserveResourcesOnDeletion = false
      }
      generators = [
        {
          clusters = {
            selector = {
              matchExpressions = [
                {
                  key      = "platform_cluster"
                  operator = "Exists"
                }
              ]
            }
          }
        }
      ]
      template = {
        metadata = {
          name = "bootstrap"
        }
        spec = {
          project = "default"
          source = {
            repoURL        = "{{ .metadata.annotations.platform_repo_url }}"
            path           = "{{ .metadata.annotations.platform_repo_path }}bootstrap"
            targetRevision = "{{ .metadata.annotations.platform_repo_revision }}"
            directory = {
              recurse = true
            }
          }
          destination = {
            namespace = "argocd"
            server    = "{{ .server }}"
          }
          syncPolicy = {
            automated = {
              allowEmpty = true
              prune      = true
            }
          }
        }
      }
    }
  }
}
