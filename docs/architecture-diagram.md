# Architecture Diagrams

## Overall Architecture

```mermaid
graph TB
    subgraph "Developer Workflow"
        DEV[Developer]
        CODE[Application Code]
        BUILD[Build & Push Image]
        MANIFEST[Update Manifests]
    end

    subgraph "AWS Cloud"
        subgraph "CodeCommit Repositories"
            PLATFORM_REPO["Platform Repository
            (bootstrap, config, namespaces)"]
            WORKLOAD_REPO["Workload Repository
            (application manifests)"]
        end

        subgraph "EKS Cluster"
            subgraph "EKS Capabilities"
                ARGOCD["Argo CD
                (Managed by AWS)"]
            end

            subgraph "Platform Components"
                ROLLOUTS[Argo Rollouts]
                CW["CloudWatch
                Observability"]
            end

            subgraph "Application Workloads"
                subgraph "ex-app Namespace"
                    BG_DEMO["bg-demo
                    (Blue/Green Rollout)"]
                    DIST_MON["distribution-monitor
                    (Blue/Green Rollout)"]
                end
            end

            subgraph "Ingress"
                ALB[Application Load Balancer]
            end
        end

        ECR["Amazon ECR
        Container Registry"]
        IDC["IAM Identity Center
        SSO Authentication"]
    end

    USER[End User]

    DEV -->|1 Write Code| CODE
    CODE -->|2 Build and Push| BUILD
    BUILD -->|3 Push Image| ECR
    DEV -->|4 Update Manifests| MANIFEST
    MANIFEST -->|5 Git Push| WORKLOAD_REPO
    
    PLATFORM_REPO -->|GitOps Sync| ARGOCD
    WORKLOAD_REPO -->|GitOps Sync| ARGOCD
    
    ARGOCD -->|Deploy| ROLLOUTS
    ARGOCD -->|Deploy| BG_DEMO
    ARGOCD -->|Deploy| DIST_MON
    
    ECR -->|Pull Image| BG_DEMO
    ECR -->|Pull Image| DIST_MON
    
    BG_DEMO --> ALB
    DIST_MON --> ALB
    
    ALB -->|HTTPS| USER
    
    IDC -->|SSO Login| ARGOCD
    DEV -->|Access UI| ARGOCD
    
    CW -.->|Monitor| BG_DEMO
    CW -.->|Monitor| DIST_MON

    style ARGOCD fill:#ff9900
    style ECR fill:#ff9900
    style IDC fill:#ff9900
    style ALB fill:#ff9900
    style CW fill:#ff9900
```

## GitOps Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as CodeCommit
    participant ArgoCD as Argo CD
    participant K8s as Kubernetes
    participant App as Application

    Dev->>Git: 1. Push manifests
    Git->>ArgoCD: 2. Detect changes
    ArgoCD->>ArgoCD: 3. Compare desired vs actual state
    ArgoCD->>K8s: 4. Apply changes
    K8s->>App: 5. Deploy/Update
    App-->>ArgoCD: 6. Report health status
    ArgoCD-->>Dev: 7. Show sync status in UI
```

## Blue/Green Deployment Flow

```mermaid
graph LR
    subgraph "Argo Rollouts"
        ROLLOUT[Rollout Controller]
    end

    subgraph "Services"
        ACTIVE["Active Service
        (Production Traffic)"]
        PREVIEW["Preview Service
        (Test Traffic)"]
    end

    subgraph "Pod Groups"
        BLUE["Blue Pods
        (Current Version)"]
        GREEN["Green Pods
        (New Version)"]
    end

    subgraph "Ingress"
        ACTIVE_ALB[Active ALB]
        PREVIEW_ALB[Preview ALB]
    end

    ROLLOUT -->|1. Deploy New Version| GREEN
    ROLLOUT -->|Keep Running| BLUE
    
    GREEN --> PREVIEW
    BLUE --> ACTIVE
    
    PREVIEW --> PREVIEW_ALB
    ACTIVE --> ACTIVE_ALB
    
    ROLLOUT -.->|2. Manual Promote| SWITCH[Switch Traffic]
    SWITCH -.->|3. Active → Green| GREEN
    SWITCH -.->|4. Terminate Blue| BLUE

    style GREEN fill:#90EE90
    style BLUE fill:#87CEEB
    style SWITCH fill:#FFD700
```

## Terraform Infrastructure Provisioning

```mermaid
graph TB
    subgraph "Terraform Configuration"
        TFVARS["terraform.tfvars
        (Variables)"]
        MAIN["main.tf
        (Module Call)"]
        MODULE[platform_cluster Module]
    end

    subgraph "AWS Resources Created"
        VPC["VPC
        (3 AZs, Private Subnets)"]
        EKS["EKS Cluster
        (Auto Mode)"]
        CAPABILITY["EKS Capability
        (Argo CD)"]
        CODECOMMIT["CodeCommit
        Repositories"]
        IAM["IAM Roles
        and Policies"]
    end

    TFVARS --> MAIN
    MAIN --> MODULE
    
    MODULE -->|Create| VPC
    MODULE -->|Create| EKS
    MODULE -->|Create| CAPABILITY
    MODULE -->|Create| CODECOMMIT
    MODULE -->|Create| IAM
    
    EKS -->|Depends On| VPC
    CAPABILITY -->|Depends On| EKS
    IAM -->|Attached To| CAPABILITY

    style MODULE fill:#7B68EE
    style EKS fill:#ff9900
    style CAPABILITY fill:#ff9900
```

## ApplicationSet Hierarchy

```mermaid
graph TD
    ROOT["bootstrap ApplicationSet
    (Root)"]
    
    ROOT --> NS["bootstrap-namespaces
    (Auto-discover namespaces)"]
    ROOT --> WL["bootstrap-workloads
    (Auto-discover workloads)"]
    ROOT --> ADDON["config-addons
    (Cluster addons)"]
    ROOT --> AUTO["config-automode
    (EKS Auto Mode config)"]
    
    NS --> NS_APP["namespace-ex-app
    (Namespace configuration)"]
    
    WL --> BG_APP["workloads-ex-app-bg-demo-dev
    (bg-demo application)"]
    WL --> DM_APP["workloads-ex-app-distribution-monitor-dev
    (distribution-monitor application)"]
    
    ADDON --> ROLLOUTS_ADDON["addon-argo-rollouts-dev
    (Argo Rollouts)"]
    
    NS_APP --> NS_RESOURCES["Namespace Resources
    (ResourceQuota, LimitRange, NetworkPolicy)"]
    BG_APP --> BG_RESOURCES["Rollout, Service, Ingress"]
    DM_APP --> DM_RESOURCES["Rollout, Service, Ingress"]
    ROLLOUTS_ADDON --> ROLLOUTS_CRD["Rollout CRDs and Controller"]

    style ROOT fill:#FF6B6B
    style NS fill:#4ECDC4
    style WL fill:#4ECDC4
    style ADDON fill:#4ECDC4
    style AUTO fill:#4ECDC4
```

## Developer Experience Flow

```mermaid
graph TB
    START([Developer Starts])
    
    START --> SETUP[1 Setup terraform apply]
    SETUP --> PUSH_INFRA[2 Push platform and workload configs to CodeCommit]
    PUSH_INFRA --> VERIFY[3 Verify bg-demo deployment in Argo CD UI]
    
    VERIFY --> BUILD[4 Build application make build and make push]
    BUILD --> CREATE[5 Create manifests in tmp workloads]
    CREATE --> PUSH_APP[6 Git push to workload repository]
    
    PUSH_APP --> WAIT[7 Wait for Argo CD auto-sync]
    WAIT --> CHECK[8 Check deployment in Argo CD UI]
    
    CHECK --> ACCESS[9 Access application via ALB URL]
    
    ACCESS --> UPDATE{Need to update?}
    UPDATE -->|Yes| CHANGE[10 Change code]
    CHANGE --> REBUILD[11 make build and make push]
    REBUILD --> UPDATE_MANIFEST[12 Update kustomization yaml with new image tag]
    UPDATE_MANIFEST --> PUSH_UPDATE[13 Git push]
    PUSH_UPDATE --> PREVIEW[14 Check Preview environment]
    PREVIEW --> PROMOTE[15 kubectl argo rollouts promote]
    PROMOTE --> ACCESS
    
    UPDATE -->|No| END([Complete])

    style START fill:#90EE90
    style END fill:#FFB6C1
    style BUILD fill:#FFD700
    style PROMOTE fill:#FF6347
```

