#!/bin/bash
set -e

# Usage: ./push-platform.sh
# Pushes the platform repository to CodeCommit

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/.."
PLATFORM_DIR="$REPO_ROOT/repositories/platform"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"
git init
git remote add origin https://git-codecommit.us-east-1.amazonaws.com/v1/repos/ex-idp-dev-platform
git config credential.helper '!aws --profile default codecommit credential-helper $@'
git config credential.UseHttpPath true

cp -r "$PLATFORM_DIR"/* .

echo "=== Files to push ==="
find . -type f -not -path './.git/*'

git add -A
git commit -m "update: platform configuration"
git branch -M main

echo ""
echo "Pushing to CodeCommit..."
GIT_CONFIG_GLOBAL=/dev/null git push --force origin main

echo ""
echo "Done! ArgoCD will sync the platform configuration."
