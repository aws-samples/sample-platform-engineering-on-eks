#!/bin/bash
set -e

# Usage: ./push-workload.sh [kro|traditional]
# Pushes the selected workload variant to CodeCommit as ex-app/bg-demo/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
WORKLOAD_DIR="$REPO_ROOT/repositories/workloads"
VARIANT="${1:-kro}"

if [[ "$VARIANT" != "kro" && "$VARIANT" != "traditional" ]]; then
  echo "Usage: $0 [kro|traditional]"
  echo "  kro          - Deploy using kro WebApp Instance (default)"
  echo "  traditional  - Deploy using Kustomize with raw manifests"
  exit 1
fi

SOURCE_DIR="$WORKLOAD_DIR/ex-app/bg-demo-${VARIANT}"

# Validate source exists
if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: $SOURCE_DIR does not exist"
  exit 1
fi

# Create temp repo and push
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"
git init
git remote add origin https://git-codecommit.us-east-1.amazonaws.com/v1/repos/ex-idp-dev-workload
git config credential.helper '!aws --profile default codecommit credential-helper $@'
git config credential.UseHttpPath true

# Copy files maintaining the expected directory structure
mkdir -p ex-app/bg-demo
cp -r "$SOURCE_DIR"/* ex-app/bg-demo/

# For traditional variant, also copy base
if [[ "$VARIANT" == "traditional" ]]; then
  # base is already inside bg-demo-traditional
  :
fi

echo "=== Files to push (variant: $VARIANT) ==="
find ex-app -type f

git add -A
git commit -m "deploy: bg-demo ($VARIANT variant)"
git branch -M main

echo ""
echo "Pushing to CodeCommit..."
GIT_CONFIG_GLOBAL=/dev/null git push --force origin main

echo ""
echo "Done! ArgoCD will sync the $VARIANT variant."
