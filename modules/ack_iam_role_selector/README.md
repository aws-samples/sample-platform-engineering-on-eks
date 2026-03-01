# ACK IAM Role Selector Module

This Terraform module creates an IAM role and IAM Role Selector for AWS Controllers for Kubernetes (ACK), enabling granular IAM permissions for specific namespaces and resource types.

## Features

- Creates an IAM role with custom permissions
- Configures trust relationship with ACK controller role
- Creates Kubernetes IAMRoleSelector CRD
- Supports namespace selection by name or labels
- Optional resource type scoping

## Prerequisites

- EKS cluster with ACK capabilities enabled
- ACK IAM Role Selector feature flag enabled (`featureGates.IAMRoleSelector=true`)
- ACK controller role ARN

## Usage

### Basic Example - Single Namespace with Inline Policy

```hcl
module "s3_permissions" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix         = "ex-idp"
  environment             = "dev"
  selector_name           = "ex-app-s3-access"
  namespace               = "default"
  ack_controller_role_arn = "arn:aws:iam::123456789012:role/ex-idp-dev-capabilities-ack"

  namespace_selector_names = ["ex-app"]

  iam_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      resources = [
        "arn:aws:s3:::my-bucket/*"
      ]
    },
    {
      effect = "Allow"
      actions = [
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::my-bucket"
      ]
    }
  ]

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

This creates IAM role: `ex-idp-dev-ex-app-s3-access-role`

### Example with AWS Managed Policy

```hcl
module "s3_full_access" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix         = "ex-idp"
  environment             = "dev"
  selector_name           = "ex-app-s3-full"
  namespace               = "default"
  ack_controller_role_arn = "arn:aws:iam::123456789012:role/ex-idp-dev-capabilities-ack"

  namespace_selector_names = ["ex-app"]

  # Use AWS managed policy
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  ]
}
```

### Example with Both Managed and Inline Policies

```hcl
module "s3_mixed_permissions" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix         = "ex-idp"
  environment             = "dev"
  selector_name           = "ex-app-s3-mixed"
  namespace               = "default"
  ack_controller_role_arn = "arn:aws:iam::123456789012:role/ex-idp-dev-capabilities-ack"

  namespace_selector_names = ["ex-app"]

  # AWS managed policy for S3 read access
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  ]

  # Additional inline policy for specific write permissions
  iam_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:DeleteObject"
      ]
      resources = [
        "arn:aws:s3:::my-specific-bucket/*"
      ]
    }
  ]
}
```

### Example with Label Selector

```hcl
module "dynamodb_permissions" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix         = "ex-idp"
  environment             = "dev"
  selector_name           = "dynamodb-dev-access"
  namespace               = "default"
  ack_controller_role_arn = "arn:aws:iam::123456789012:role/ex-idp-dev-capabilities-ack"

  namespace_selector_names = []  # Empty to use label selector only
  namespace_selector_labels = {
    environment = "development"
    team        = "backend"
  }

  iam_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ]
      resources = [
        "arn:aws:dynamodb:us-west-2:123456789012:table/my-table"
      ]
    }
  ]
}
```

### Example with Resource Type Selector

```hcl
module "s3_buckets_only" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix         = "ex-idp"
  environment             = "prod"
  selector_name           = "s3-buckets-only"
  namespace               = "default"
  ack_controller_role_arn = "arn:aws:iam::123456789012:role/ex-idp-prod-capabilities-ack"

  namespace_selector_names = ["production"]

  resource_type_selectors = [
    {
      group   = "s3.services.k8s.aws"
      version = "v1alpha1"
      kind    = "Bucket"
    }
  ]

  iam_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucketPolicy"
      ]
      resources = ["*"]
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| resource_prefix | Prefix for resource names (e.g., 'ex-idp') | string | - | yes |
| environment | Environment name (e.g., 'dev', 'prod') | string | - | yes |
| selector_name | Name of the IAM Role Selector resource | string | - | yes |
| namespace | Kubernetes namespace where the IAM Role Selector will be created | string | - | yes |
| ack_controller_role_arn | ARN of the ACK controller role | string | - | yes |
| iam_policy_statements | List of IAM policy statements for inline policy | list(object) | [] | no |
| managed_policy_arns | List of AWS managed or customer managed policy ARNs | list(string) | [] | no |
| namespace_selector_names | List of namespace names to match | list(string) | [] | no |
| namespace_selector_labels | Map of labels to match namespaces | map(string) | {} | no |
| resource_type_selectors | List of resource types to scope | list(object) | [] | no |
| tags | Tags to apply to AWS resources | map(string) | {} | no |

**Note**: You must provide either `iam_policy_statements` or `managed_policy_arns` (or both).

## Naming Convention

IAM resources follow the pattern: `{resource_prefix}-{environment}-{selector_name}-{resource_type}`

Examples:
- IAM Role: `ex-idp-dev-ex-app-s3-access-role`
- IAM Policy: `ex-idp-dev-ex-app-s3-access-policy`

This ensures uniqueness across multiple clusters in the same AWS account.

## Outputs

| Name | Description |
|------|-------------|
| role_arn | ARN of the created IAM role |
| role_name | Name of the created IAM role |
| selector_name | Name of the IAM Role Selector |

## Selection Logic

- If exactly one IAMRoleSelector matches, that role is used
- If no IAMRoleSelector matches, the default controller role is used
- If multiple IAMRoleSelectors match, a conflict occurs and the resource shows an error

## References

- [ACK IAM Role Selector Documentation](https://aws-controllers-k8s.github.io/docs/guides/cross-account)
