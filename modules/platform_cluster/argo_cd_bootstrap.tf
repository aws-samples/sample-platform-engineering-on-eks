// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: MIT-0


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
