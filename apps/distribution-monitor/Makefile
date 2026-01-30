.PHONY: help build push clean run test deploy undeploy status logs

# Default container runtime
RUNTIME ?= docker

# Platform architecture (default: multi-platform)
PLATFORM ?= linux/amd64,linux/arm64

# Get Git hash
GIT_HASH := $(shell git rev-parse --short HEAD)

# Image name and tag
IMAGE_NAME := distribution-monitor
IMAGE_TAG := $(GIT_HASH)

# ECR settings (can be overridden by environment variables)
AWS_REGION ?= $(shell aws configure get region 2>/dev/null || echo "ap-northeast-1")
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
ECR_REGISTRY := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

help: ## Show help message
	@echo "Distribution Monitor - Makefile"
	@echo ""
	@echo "Usage:"
	@echo "  make <target> [RUNTIME=docker|finch]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make build                    # Build multi-arch (amd64+arm64)"
	@echo "  make build PLATFORM=linux/amd64 # Build amd64 only"
	@echo "  make build PLATFORM=linux/arm64 # Build arm64 only"
	@echo "  make build RUNTIME=finch      # Build with finch"
	@echo "  make login-public             # Login to ECR Public"
	@echo "  make create-repo              # Auto-detect AWS account"
	@echo "  make push                     # Auto-detect AWS account"
	@echo "  make push AWS_ACCOUNT_ID=123456789012  # Override account ID"
	@echo "  make deploy                   # Deploy to Kubernetes"
	@echo "  make status                   # Check deployment status"

build-no-login: ## Build container image without ECR Public login
	@echo "Building with $(RUNTIME)..."
	@echo "Platform: $(PLATFORM)"
	@echo "Image: $(IMAGE_NAME):$(IMAGE_TAG)"
	$(RUNTIME) build \
		--platform $(PLATFORM) \
		--build-arg GIT_HASH=$(GIT_HASH) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-t $(IMAGE_NAME):latest \
		.
	@echo "Build complete!"

build: login-public build-no-login ## Build container image with ECR Public login

tag: ## Tag image for ECR
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: AWS_ACCOUNT_ID could not be determined"; \
		echo "Please set AWS_ACCOUNT_ID environment variable or configure AWS CLI"; \
		echo "Usage: make tag AWS_ACCOUNT_ID=123456789012"; \
		exit 1; \
	fi
	@echo "Tagging image for ECR..."
	$(RUNTIME) tag $(IMAGE_NAME):$(IMAGE_TAG) $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	$(RUNTIME) tag $(IMAGE_NAME):$(IMAGE_TAG) $(ECR_REGISTRY)/$(IMAGE_NAME):latest
	@echo "Tagged: $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

login: ## Login to ECR
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: AWS_ACCOUNT_ID could not be determined"; \
		echo "Please set AWS_ACCOUNT_ID environment variable or configure AWS CLI"; \
		echo "Usage: make login AWS_ACCOUNT_ID=123456789012"; \
		exit 1; \
	fi
	@echo "Logging in to ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | \
		$(RUNTIME) login --username AWS --password-stdin $(ECR_REGISTRY)

login-public: ## Login to ECR Public
	@echo "Logging in to ECR Public..."
	aws ecr-public get-login-password --region us-east-1 | \
		$(RUNTIME) login --username AWS --password-stdin public.ecr.aws

create-repo: ## Create ECR repository if it doesn't exist
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: AWS_ACCOUNT_ID could not be determined"; \
		echo "Please set AWS_ACCOUNT_ID environment variable or configure AWS CLI"; \
		echo "Usage: make create-repo AWS_ACCOUNT_ID=123456789012"; \
		exit 1; \
	fi
	@echo "Checking if ECR repository exists..."
	@aws ecr describe-repositories --repository-names $(IMAGE_NAME) --region $(AWS_REGION) > /dev/null 2>&1 || \
		(echo "Repository does not exist. Creating..." && \
		aws ecr create-repository \
			--repository-name $(IMAGE_NAME) \
			--region $(AWS_REGION) \
			--image-scanning-configuration scanOnPush=true \
			--encryption-configuration encryptionType=AES256 && \
		echo "Repository created successfully!")
	@echo "Repository is ready."

push: tag create-repo ## Push image to ECR
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: AWS_ACCOUNT_ID could not be determined"; \
		echo "Please set AWS_ACCOUNT_ID environment variable or configure AWS CLI"; \
		echo "Usage: make push AWS_ACCOUNT_ID=123456789012"; \
		exit 1; \
	fi
	@echo "Pushing to ECR..."
	@if [ "$(RUNTIME)" = "finch" ]; then \
		echo "Using finch with --all-platforms..."; \
		$(RUNTIME) push --all-platforms $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
		$(RUNTIME) push --all-platforms $(ECR_REGISTRY)/$(IMAGE_NAME):latest; \
	else \
		$(RUNTIME) push $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
		$(RUNTIME) push $(ECR_REGISTRY)/$(IMAGE_NAME):latest; \
	fi
	@echo "Push complete!"

run: ## Run container locally
	@echo "Running container..."
	$(RUNTIME) run -d \
		-p 8080:8080 \
		-e POD_ID=local-dev \
		-e APP_VERSION=$(GIT_HASH) \
		--name $(IMAGE_NAME) \
		$(IMAGE_NAME):latest
	@echo "Container started at http://localhost:8080"

stop: ## Stop running container
	@echo "Stopping container..."
	-$(RUNTIME) stop $(IMAGE_NAME)
	-$(RUNTIME) rm $(IMAGE_NAME)

clean: stop ## Remove local images
	@echo "Removing local images..."
	-$(RUNTIME) rmi $(IMAGE_NAME):$(IMAGE_TAG)
	-$(RUNTIME) rmi $(IMAGE_NAME):latest

deploy: ## Deploy to Kubernetes
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: AWS_ACCOUNT_ID could not be determined"; \
		echo "Please set AWS_ACCOUNT_ID environment variable or configure AWS CLI"; \
		exit 1; \
	fi
	@echo "Deploying to Kubernetes..."
	@echo "Image: $(ECR_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"
	@sed "s|<account-id>|$(AWS_ACCOUNT_ID)|g; s|<region>|$(AWS_REGION)|g; s|<git-hash>|$(IMAGE_TAG)|g" \
		k8s/deployment.yaml | kubectl apply -f -
	@echo "Deployment complete!"
	@echo "Check status with: kubectl get pods -l app=distribution-monitor"

undeploy: ## Remove deployment from Kubernetes
	@echo "Removing deployment from Kubernetes..."
	kubectl delete -f k8s/deployment.yaml --ignore-not-found
	@echo "Undeployment complete!"

status: ## Check deployment status
	@echo "Deployment status:"
	@kubectl get deployment distribution-monitor -o wide 2>/dev/null || echo "Deployment not found"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -l app=distribution-monitor -o wide
	@echo ""
	@echo "Service:"
	@kubectl get svc distribution-monitor -o wide 2>/dev/null || echo "Service not found"
	@echo ""
	@echo "Ingress:"
	@kubectl get ingress distribution-monitor 2>/dev/null || echo "Ingress not found"
	@echo ""
	@echo "Ingress URL:"
	@kubectl get ingress distribution-monitor -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null && echo "" || echo "Waiting for ALB provisioning..."

logs: ## Show logs from pods
	@echo "Fetching logs from distribution-monitor pods..."
	@kubectl logs -l app=distribution-monitor --tail=50 --prefix=true

test: ## Run Gradle tests
	./gradlew test

gradle-build: ## Run Gradle build
	./gradlew build

info: ## Show build information
	@echo "Runtime:      $(RUNTIME)"
	@echo "Platform:     $(PLATFORM)"
	@echo "Git Hash:     $(GIT_HASH)"
	@echo "Image Name:   $(IMAGE_NAME)"
	@echo "Image Tag:    $(shell $(MAKE) -s image-tag 2>/dev/null || echo "$(IMAGE_TAG) [local]")"
	@echo "AWS Region:   $(AWS_REGION) $(if $(filter $(AWS_REGION),$(shell aws configure get region 2>/dev/null || echo "")),[auto-detected],[default])"
	@echo "AWS Account:  $(if $(AWS_ACCOUNT_ID),$(AWS_ACCOUNT_ID) [auto-detected],<not detected>)"
	@echo "ECR Registry: $(ECR_REGISTRY)"

image-repo: ## Output image repository only
	@echo "$(ECR_REGISTRY)/$(IMAGE_NAME)"

image-tag: ## Output latest pushed image tag from ECR
	@if [ -z "$(AWS_ACCOUNT_ID)" ]; then \
		echo "Error: AWS_ACCOUNT_ID could not be determined" >&2; \
		exit 1; \
	fi
	@TAG=$$(aws ecr describe-images \
		--repository-name $(IMAGE_NAME) \
		--region $(AWS_REGION) \
		--image-ids imageTag=latest \
		--query 'imageDetails[0].imageTags[?@ != `latest`] | [0]' \
		--output text 2>&1); \
	if [ $$? -ne 0 ]; then \
		echo "Error: Failed to retrieve image tag from ECR" >&2; \
		echo "$$TAG" >&2; \
		exit 1; \
	fi; \
	if [ -z "$$TAG" ] || [ "$$TAG" = "None" ]; then \
		echo "Error: No image tag found for 'latest' in ECR repository $(IMAGE_NAME)" >&2; \
		echo "Please run 'make push' first to push an image to ECR" >&2; \
		exit 1; \
	fi; \
	echo "$$TAG"

image-full: ## Output full image name (repository:tag)
	@echo "$(ECR_REGISTRY)/$(IMAGE_NAME):$(shell $(MAKE) -s image-tag)"

all: build ## Build (default target)

.DEFAULT_GOAL := help
