# Amazon EKS Platform Engineering Reference Architecture

[日本語版はこちら / Japanese version](README.ja.md)

> This repository provides a reference implementation for educational and demonstration purposes only. This code is NOT production-ready and should NOT be deployed to production environments without additional security testing, hardening, and validation.

This repository provides a reference implementation for Platform Engineering using Amazon EKS and Argo CD. It demonstrates declarative infrastructure management based on GitOps and a self-service platform for developers.

## Overview

This project demonstrates an Internal Developer Platform (IDP) composed of the following elements:

- **EKS Auto Mode**: Managed Kubernetes cluster with automated compute and storage management
- **EKS Capabilities - Argo CD**: Fully managed Argo CD provided by AWS (installation, upgrades, and operations managed by AWS)
- **Argo Rollouts**: Advanced deployment strategies such as Blue/Green deployments
- **Multi-tenancy**: Namespace-based multi-tenant configuration
- **Observability**: Integrated monitoring with CloudWatch

## Architecture

### Directory Structure

```
.
├── modules/platform_cluster/     # Terraform module (EKS cluster definition)
├── environments/                 # Environment-specific Terraform configurations
│   └── sample/                  # Sample environment
├── repositories/
│   ├── platform/                # Platform configuration repository
│   │   ├── bootstrap/          # Argo CD bootstrap configuration
│   │   ├── charts/             # Helm charts (namespace-config, etc.)
│   │   ├── config/             # Addon configurations (Argo Rollouts, etc.)
│   │   └── namespaces/         # Namespace definitions and workload configurations
│   └── workloads/              # Application manifest repository
│       └── bg-demo/            # Blue/Green deployment demo
└── apps/
    └── distribution-monitor/    # Sample application (load distribution visualization)
```

### Components

#### 1. Platform Cluster Module
Build an EKS cluster with Terraform:
- **EKS Auto Mode**: Automated node and storage management
- **VPC**: Private network with 3 AZ configuration
- **EKS Capabilities - Argo CD**: AWS fully managed Argo CD (automatic installation and upgrades)
- **CloudWatch Observability**: Integrated monitoring with Application Signals
- **IAM Identity Center**: SSO authentication for Argo CD (built-in feature of managed version)

#### 2. GitOps Bootstrap
Hierarchical automated deployment with Argo CD ApplicationSet:

```
bootstrap (Root ApplicationSet)
├── bootstrap-namespaces    # Auto-discover and deploy namespace configurations
├── bootstrap-workloads     # Auto-discover and deploy workloads
├── config-addons          # Cluster addons (Argo Rollouts, etc.)
└── config-automode        # EKS Auto Mode configuration
```

#### 3. Multi-tenancy
Standardized namespace management with Helm chart `namespace-config`:
- Resource Quota
- Limit Range
- Network Policy
- RBAC

#### 4. Sample Application
**Distribution Monitor**: Spring Boot application that visualizes load distribution across Pods
- Blue/Green deployment with Argo Rollouts
- External exposure via ALB Ingress
- Cookie-based request tracking

## Quick Start

### Prerequisites

- AWS CLI (configured)
- Terraform >= 1.0
- kubectl
- [AWS IAM Identity Center (for Argo CD SSO)](https://docs.aws.amazon.com/eks/latest/userguide/argocd-create-console.html#_prerequisites)
  - [Getting Started (IAM Identity Center)](https://docs.aws.amazon.com/singlesignon/latest/userguide/getting-started.html)

### 1. Configure Terraform Variables

```bash
cd environments/sample
cat << EOF > terraform.tfvars
# AWS profile name (configured in ~/.aws/config)
aws_profile = "your-aws-profile"

# AWS region for deployment
aws_region = "ap-northeast-1"

# Resource name prefix (to avoid name conflicts in AWS account)
resource_prefix = "ex-idp"

# IAM Identity Center region (for Argo CD SSO authentication)
argo_cd_idc_region = "ap-northeast-1"

# IAM Identity Center instance ARN (for Argo CD SSO authentication)
argo_cd_idc_instance_arn = "arn:aws:sso:::instance/ssoins-xxxxxxxxxx"

# Identity Center groups to grant Argo CD admin permissions
# Key: group ID, Value: group name
argo_cd_idc_groups = {
  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" = "ADMIN"
}
EOF
```

> **Note**: In the sample environment, CodeCommit repositories are automatically created, so you don't need to manually configure Git repository URLs.

### 2. Deploy the Cluster

```bash
terraform init
terraform plan
terraform apply
```

Deployment takes approximately 15-20 minutes.

### 3. Connect to the Cluster

```bash
export AWS_REGION=ap-northeast-1
aws eks update-kubeconfig --name ex-idp-dev-cluster
kubectl get nodes
```

### 4. Access Argo CD

The EKS Capabilities managed version of Argo CD is accessed via a dedicated URL managed by AWS:

```bash
# Set AWS region
export AWS_REGION=ap-northeast-1

# Get Argo CD URL
aws eks describe-capability \
  --cluster-name ex-idp-dev-cluster \
  --capability-name argocd \
  --query 'capability.configuration.argoCd.serverUrl' \
  --output text
```

Access the retrieved URL in your browser and log in with IAM Identity Center. Authentication is automatically configured in the managed version.

> **Note**: Since EKS Capabilities Argo CD is a fully managed service, you cannot directly access Services or Pods within the cluster. Use the dedicated URL provided by AWS.

### 5. Push Code to CodeCommit Repositories

To enable Argo CD to deploy applications via GitOps, push platform configurations and workload manifests to CodeCommit.

To manage them as separate repositories from this reference architecture repository, copy them to the `environments/sample/tmp` directory before operating.

```bash
cd environments/sample

# Get CodeCommit repository URLs
export PLATFORM_REPO_URL=$(terraform output -raw platform_repo_url)
export WORKLOAD_REPO_URL=$(terraform output -raw workload_repo_url)

echo "Platform Repository: $PLATFORM_REPO_URL"
echo "Workload Repository: $WORKLOAD_REPO_URL"

# Create working directory
mkdir -p tmp

# Copy and push platform configuration
cp -r ../../repositories/platform tmp/platform
cd tmp/platform
git init
git add .
git commit -m "Initial platform configuration"
git remote add origin $PLATFORM_REPO_URL
git push -u origin main

# Copy and push workload manifests
cd ..
cp -r ../../../repositories/workloads tmp/workloads
cd workloads
git init
git add .
git commit -m "Initial workload manifests"
git remote add origin $WORKLOAD_REPO_URL
git push -u origin main

# Return to original directory
cd ../../..
```

> **Note**: For CodeCommit authentication, use the AWS CLI credential helper or git-remote-codecommit. See [AWS CodeCommit Documentation](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up.html) for details.

### Verify Setup

bg-demo is a [sample workload](https://github.com/argoproj/rollouts-demo) to verify platform setup. It has already been deployed by the above steps.

#### Verify Deployment

1. Access Argo CD UI
2. Verify that the `bootstrap` ApplicationSet has automatically generated the following Applications:
   - `bootstrap-namespaces`: Namespace configuration
   - `bootstrap-workloads`: Workload configuration
   - `config-addons`: Addons like Argo Rollouts
3. Verify that `workloads-ex-app-bg-demo-dev` Application is created and synced
4. Click the Application to verify Rollout, Service, and Ingress resources

#### Access the Application

```bash
# Get Ingress URLs
kubectl get ingress -n ex-app bg-demo-active -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress -n ex-app bg-demo-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Access the retrieved URL in your browser to verify the application is running.

## Deploy Application as a Developer

After verifying the setup works correctly, deploy a new application as a developer.

Distribution Monitor is a Spring Boot application that visualizes load distribution across Pods.

### Step 1: Build and Push Application

```bash
cd apps/distribution-monitor

# Push image to ECR
make login
make build
make push

# Set image information to environment variables
export IMAGE_REPO=$(make image-repo)
export IMAGE_TAG=$(make image-tag)

# Verify
echo "Image Repository: $IMAGE_REPO"
echo "Image Tag: $IMAGE_TAG"
```

### Step 2: Create Kubernetes Manifests

Create a directory for the new application in the workload repository.

```bash
# Navigate to workload repository directory
cd environments/sample/tmp/workloads/ex-app

# Create distribution-monitor directory
mkdir -p distribution-monitor/base
mkdir -p distribution-monitor/dev
```

#### Create base/rollouts.yaml

```bash
cat << 'EOF' > distribution-monitor/base/rollouts.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: distribution-monitor
spec:
  replicas: 2
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: distribution-monitor
  template:
    metadata:
      labels:
        app.kubernetes.io/name: distribution-monitor
    spec:
      containers:
      - name: distribution-monitor
        image: distribution-monitor
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        env:
        - name: POD_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
  strategy:
    blueGreen: 
      activeService: distribution-monitor-active
      previewService: distribution-monitor-preview
      autoPromotionEnabled: false
EOF
```

#### Create base/service.yaml

```bash
cat << 'EOF' > distribution-monitor/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: distribution-monitor-active
  labels:
    app.kubernetes.io/name: distribution-monitor
spec:
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: distribution-monitor

---
apiVersion: v1
kind: Service
metadata:
  name: distribution-monitor-preview
  labels:
    app.kubernetes.io/name: distribution-monitor
spec:
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: distribution-monitor
EOF
```

#### Create base/ingress.yaml

```bash
cat << 'EOF' > distribution-monitor/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: distribution-monitor-active
spec:
  rules:
    - http:
        paths:
          - path: /*
            pathType: ImplementationSpecific
            backend:
              service:
                name: distribution-monitor-active
                port:
                  name: http

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: distribution-monitor-preview
spec:
  rules:
    - http:
        paths:
          - path: /*
            pathType: ImplementationSpecific
            backend:
              service:
                name: distribution-monitor-preview
                port:
                  name: http
EOF
```

#### Create base/kustomization.yaml

```bash
cat << EOF > distribution-monitor/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ex-app
resources:
- ingress.yaml
- service.yaml
- rollouts.yaml
images:
- name: distribution-monitor
  newName: ${IMAGE_REPO}
  newTag: ${IMAGE_TAG}
EOF
```

#### Create dev/kustomization.yaml

```bash
cat << 'EOF' > distribution-monitor/dev/kustomization.yaml
kind: Kustomization
resources:
- ../base
EOF
```

### Step 3: Push to CodeCommit

```bash
# Navigate to workload repository root
cd ../..

# Commit and push changes
git add .
git commit -m "Add distribution-monitor application"
git push
```

### Step 4: Verify Deployment in Argo CD

1. Access Argo CD UI
2. After a few seconds to minutes, `workloads-ex-app-distribution-monitor-dev` Application will be automatically created
3. Click the Application to verify resource sync status
4. Wait until all resources are Healthy

### Step 5: Access the Application

```bash
# Get Active environment URL
kubectl get ingress -n ex-app distribution-monitor-active -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get Preview environment URL
kubectl get ingress -n ex-app distribution-monitor-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Access the Active environment URL in your browser to verify Distribution Monitor is running. Each page refresh records which Pod responded, visualizing the load distribution.

### Verify Blue/Green Deployment

#### Deploy New Version

1. Update application code and image:

```bash
cd apps/distribution-monitor
# Make code changes (e.g., src/main/resources/templates/index.html)
make build
make push

# Update environment variable with new image information
export IMAGE_TAG=$(make image-tag)
echo "New Image Tag: $IMAGE_TAG"
```

2. Update and push manifests:

```bash
cd environments/sample/tmp/workloads/ex-app/distribution-monitor/base

# Update newTag in kustomization.yaml
sed -i.bak "s/newTag: .*/newTag: ${IMAGE_TAG}/" kustomization.yaml

# Verify changes
cat kustomization.yaml

# Navigate to workload repository root
cd ../..

git add .
git commit -m "Update distribution-monitor to new version ${IMAGE_TAG}"
git push
```

3. Argo CD automatically detects changes and deploys the new version to the Preview environment

#### Rollout Operations

```bash
# Check Rollout status
kubectl argo rollouts get rollout distribution-monitor -n ex-app

# Get Preview environment URL and verify
kubectl get ingress -n ex-app distribution-monitor-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# If no issues, manually Promote to switch to Active environment
kubectl argo rollouts promote distribution-monitor -n ex-app

# Rollback if needed
kubectl argo rollouts undo distribution-monitor -n ex-app
```

You can also visually verify Rollout status in the Argo CD UI. Blue/Green deployment allows you to verify the new version in the Preview environment before safely switching to production (Active).

For more details, see [apps/distribution-monitor/README.md](apps/distribution-monitor/README.md).

## Key Features

### EKS Capabilities - Managed Argo CD
- **Fully Managed**: AWS automatically manages Argo CD installation, upgrades, and patching
- **IAM Identity Center Integration**: SSO authentication is automatically configured, simplifying user management
- **High Availability**: AWS automatically manages HA configuration
- **Security**: Configuration based on AWS best practices
- Details: [Amazon EKS Capabilities - Argo CD](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)

### Automated Deployment with GitOps
- Automatically reflected in cluster on Git repository push
- Dynamic Application generation with ApplicationSet
- Environment-specific configuration overrides (Kustomize)

### Multi-tenancy
- Namespace-level isolation and resource limits
- Standardized configuration with Helm charts
- Environment-specific customization with values files

### Advanced Deployment Strategies
- Blue/Green deployment with Argo Rollouts
- Safe releases with manual Promotion
- Rollback capability

### Integrated Monitoring
- CloudWatch Container Insights
- Automatic instrumentation with Application Signals
- Tracing for Java, Python, .NET, Node.js applications

## Customization

### Adding a New Namespace

1. Create a new directory in `repositories/platform/namespaces/`
2. Define namespace configuration in `config/config.yaml`
3. Place workload ApplicationSet in `workloads/`
4. Automatically deployed on Git push

### Adding a New Addon

1. Create ApplicationSet in `repositories/platform/config/addons/`
2. Place environment-specific values files
3. `config-addons.yaml` automatically detects and deploys

## Troubleshooting

### Check EKS Capabilities - Argo CD Status
```bash
# Check Capability status
aws eks describe-capability \
  --cluster-name ex-idp-dev-cluster \
  --capability-name argocd

# Check Argo CD Pod status
kubectl get pods -n argocd
```

In the managed version, AWS manages Argo CD operations, so AWS automatically handles component failures.

### ApplicationSet Not Generating Applications
```bash
kubectl get applicationset -n argocd
kubectl describe applicationset bootstrap -n argocd

# Check Cluster Secret (used by ApplicationSet generator)
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster
```

### EKS Auto Mode Nodes Not Starting
```bash
kubectl get nodeclaim
kubectl describe nodeclaim <nodeclaim-name>
```

## Cleanup

```bash
cd environments/sample
terraform destroy
```

## References

- [Amazon EKS Capabilities - Argo CD](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)
- [Amazon EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## License

This project is released under the MIT-0 License.
