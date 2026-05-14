# プラットフォームエンジニアリング リファレンスアーキテクチャ (Amazon EKS 利用)

> このリポジトリは、教育およびデモンストレーション目的のリファレンス実装を提供します。追加のセキュリティテスト、強化、検証なしにそのまま本番環境にデプロイしないでください。

Amazon EKS と Argo CD を活用した Platform Engineering のリファレンス実装です。GitOps ベースの宣言的なインフラ管理と、開発者向けのセルフサービス型プラットフォームを実現します。

## 概要

このプロジェクトは、以下の要素で構成される Internal Developer Platform (IDP) のデモンストレーションです：

- **EKS Auto Mode**: マネージド型の Kubernetes クラスター（コンピュートとストレージの自動管理）
- **EKS Capabilities - Argo CD**: AWS がフルマネージドで提供する Argo CD（インストール・アップグレード・運用を AWS が管理）
- **EKS Capabilities - kro**: Kubernetes Resource Orchestrator によるカスタム API 抽象化（Developer の認知負荷を削減）
- **EKS Capabilities - ACK**: AWS Controllers for Kubernetes（AWS リソースを宣言的に管理）
- **Argo Rollouts**: Blue/Green デプロイメントなどの高度なデプロイ戦略
- **Multi-tenancy**: Namespace ベースのマルチテナント構成
- **Observability**: CloudWatch による統合監視

## アーキテクチャ

### ディレクトリ構造

```
.
├── modules/platform_cluster/     # Terraform モジュール（EKS クラスター定義）
├── environments/                 # 環境別の Terraform 設定
│   └── sample/                  # サンプル環境
├── repositories/
│   ├── platform/                # プラットフォーム設定リポジトリ
│   │   ├── bootstrap/          # Argo CD ブートストラップ設定
│   │   ├── charts/             # Helm チャート（namespace-config など）
│   │   ├── config/             # アドオンおよび kro 設定
│   │   │   ├── addons/         # クラスターアドオン（Argo Rollouts など）
│   │   │   ├── automode/       # EKS Auto Mode 設定
│   │   │   └── kro-definitions/ # kro ResourceGraphDefinition
│   │   └── namespaces/         # Namespace 定義とワークロード設定
│   └── workloads/              # アプリケーションマニフェストリポジトリ
│       └── ex-app/
│           ├── bg-demo-kro/         # kro 版（アプリ1つにつき1ファイル）
│           └── bg-demo-traditional/ # 従来の Kustomize 版
├── scripts/
│   ├── push-platform.sh         # platform リポジトリを CodeCommit に push
│   └── push-workload.sh         # workload リポジトリを CodeCommit に push（kro/traditional 切替）
└── apps/
    └── distribution-monitor/    # サンプルアプリケーション（負荷分散可視化）
```

### コンポーネント

#### 1. Platform Cluster Module
Terraform で EKS クラスターを構築します：
- **EKS Auto Mode**: ノードとストレージの自動管理
- **VPC**: 3 AZ 構成のプライベートネットワーク
- **EKS Capabilities - Argo CD**: AWS フルマネージド版 Argo CD（自動インストール・アップグレード）
- **EKS Capabilities - ACK**: AWS Controllers for Kubernetes（K8s から AWS リソースを管理）
- **EKS Capabilities - kro**: Kubernetes Resource Orchestrator（カスタム API 抽象化）
- **CloudWatch Observability**: Application Signals による統合監視
- **IAM Identity Center**: Argo CD の SSO 認証（マネージド版の組み込み機能）

#### 2. GitOps ブートストラップ
Argo CD ApplicationSet による階層的な自動デプロイ：

```
bootstrap (Root ApplicationSet)
├── bootstrap-namespaces    # Namespace 設定の自動検出とデプロイ
├── bootstrap-workloads     # ワークロードの自動検出とデプロイ
├── config-addons          # クラスターアドオン（Argo Rollouts など）
├── config-automode        # EKS Auto Mode 設定
└── config-kro-definitions # kro ResourceGraphDefinition
```

#### 3. Multi-tenancy
Helm チャート `namespace-config` による標準化された Namespace 管理：
- Resource Quota
- Limit Range
- Network Policy
- RBAC

#### 4. サンプルアプリケーション
**Distribution Monitor**: Pod 間の負荷分散を可視化する Spring Boot アプリケーション
- Argo Rollouts による Blue/Green デプロイメント
- ALB Ingress による外部公開
- Cookie ベースのリクエスト追跡

## クイックスタート

### 前提条件

- AWS CLI（設定済み）
- Terraform >= 1.0
- kubectl
- [AWS IAM Identity Center (Argo CD SSO用)](https://docs.aws.amazon.com/ja_jp/eks/latest/userguide/argocd-create-console.html#_prerequisites)
  - [Getting Started (IAM Identity Center)](https://docs.aws.amazon.com/ja_jp/singlesignon/latest/userguide/getting-started.html)

### 1. Terraform 変数の設定

```bash
cd environments/sample
cat << EOF > terraform.tfvars
# AWS プロファイル名（~/.aws/config で設定したプロファイル）
aws_profile = "your-aws-profile"

# デプロイ先の AWS リージョン
aws_region = "ap-northeast-1"

# リソース名のプレフィックス（AWS アカウント内での名前の衝突を避けるため）
resource_prefix = "ex-idp"

# IAM Identity Center のリージョン（Argo CD の SSO 認証に使用）
argo_cd_idc_region = "ap-northeast-1"

# IAM Identity Center のインスタンス ARN（Argo CD の SSO 認証に使用）
argo_cd_idc_instance_arn = "arn:aws:sso:::instance/ssoins-xxxxxxxxxx"

# Argo CD の管理者権限を付与する Identity Center グループ
# キー: グループ ID、値: グループ名
argo_cd_idc_groups = {
  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" = "ADMIN"
}
EOF
```

> **注**: sample 環境では、CodeCommit リポジトリが自動的に作成されるため、Git リポジトリの URL を手動で設定する必要はありません。

### 2. クラスターのデプロイ

```bash
terraform init
terraform plan
terraform apply
```

デプロイには約 15-20 分かかります。

### 3. クラスターへの接続

```bash
export AWS_REGION=ap-northeast-1
aws eks update-kubeconfig --name ex-idp-dev-cluster
kubectl get nodes
```

### 4. Argo CD へのアクセス

EKS Capabilities のマネージド版 Argo CD は、AWS が管理する専用の URL からアクセスします：

```bash
# AWS リージョンを設定
export AWS_REGION=ap-northeast-1

# Argo CD の URL を取得
aws eks describe-capability \
  --cluster-name ex-idp-dev-cluster \
  --capability-name argocd \
  --query 'capability.configuration.argoCd.serverUrl' \
  --output text
```

ブラウザで取得した URL にアクセスし、IAM Identity Center でログインします。マネージド版では、認証設定が自動的に構成されます。

> **注**: EKS Capabilities の Argo CD はフルマネージドサービスのため、クラスター内の Service や Pod に直接アクセスすることはできません。AWS が提供する専用 URL を使用してください。

### 5. CodeCommit リポジトリへのコードのプッシュ

Argo CD が GitOps でアプリケーションをデプロイするため、プラットフォーム設定とワークロードマニフェストを CodeCommit にプッシュします。

このリファレンスアーキテクチャのリポジトリとは別のリポジトリとして管理するため、`environments/sample/tmp`ディレクトリにコピーしてから操作します。

```bash
cd environments/sample

# CodeCommit リポジトリの URL を取得
export PLATFORM_REPO_URL=$(terraform output -raw platform_repo_url)
export WORKLOAD_REPO_URL=$(terraform output -raw workload_repo_url)

echo "Platform Repository: $PLATFORM_REPO_URL"
echo "Workload Repository: $WORKLOAD_REPO_URL"

# 作業ディレクトリを作成
mkdir -p tmp

# プラットフォーム設定をコピーしてプッシュ
cp -r ../../repositories/platform tmp/platform
cd tmp/platform
git init
git add .
git commit -m "Initial platform configuration"
git remote add origin $PLATFORM_REPO_URL
git push -u origin main

# ワークロードマニフェストをコピーしてプッシュ
cd ..
cp -r ../../../repositories/workloads tmp/workloads
cd workloads
git init
git add .
git commit -m "Initial workload manifests"
git remote add origin $WORKLOAD_REPO_URL
git push -u origin main

# 元のディレクトリに戻る
cd ../../..
```

> **注**: CodeCommit への認証には、AWS CLI の認証情報ヘルパーまたは git-remote-codecommit を使用してください。詳細は [AWS CodeCommit のドキュメント](https://docs.aws.amazon.com/codecommit/latest/userguide/setting-up.html)を参照してください。

### セットアップの確認

bg-demo は、プラットフォームのセットアップを確認するための[サンプルワークロード](https://github.com/argoproj/rollouts-demo)です。上記の手順により既にデプロイされています。

#### デプロイの確認

1. Argo CD UI にアクセス
2. `bootstrap` ApplicationSet が以下の Application を自動生成していることを確認：
   - `bootstrap-namespaces`: Namespace 設定
   - `bootstrap-workloads`: ワークロード設定
   - `config-addons`: Argo Rollouts などのアドオン
3. `workloads-ex-app-bg-demo-dev` Application が作成され、同期されていることを確認
4. Application をクリックして、Rollout、Service、Ingress のリソースを確認

#### アプリケーションへのアクセス

```bash
# Ingress の URL を取得
kubectl get ingress -n ex-app bg-demo-active -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get ingress -n ex-app bg-demo-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

ブラウザで取得した URL にアクセスして、アプリケーションが動作していることを確認します。

## 開発者としてアプリケーションをデプロイ

セットアップが正常に動作することを確認したら、開発者として新しいアプリケーションをデプロイします。

Distribution Monitor は、Pod 間の負荷分散を可視化する Spring Boot アプリケーションです。

### ステップ1: アプリケーションのビルドとプッシュ

```bash
cd apps/distribution-monitor

# ECR にイメージをプッシュ
make login
make build
make push

# イメージ情報を環境変数に設定
export IMAGE_REPO=$(make image-repo)
export IMAGE_TAG=$(make image-tag)

# 確認
echo "Image Repository: $IMAGE_REPO"
echo "Image Tag: $IMAGE_TAG"
```

### ステップ2: Kubernetes マニフェストの作成

ワークロードリポジトリに新しいアプリケーション用のディレクトリを作成します。

```bash
# ワークロードリポジトリのディレクトリに移動
cd environments/sample/tmp/workloads/ex-app

# distribution-monitor ディレクトリを作成
mkdir -p distribution-monitor/base
mkdir -p distribution-monitor/dev
```

#### base/rollouts.yaml を作成

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

#### base/service.yaml を作成

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

#### base/ingress.yaml を作成

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

#### base/kustomization.yaml を作成

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

#### dev/kustomization.yaml を作成

```bash
cat << 'EOF' > distribution-monitor/dev/kustomization.yaml
kind: Kustomization
resources:
- ../base
EOF
```

### ステップ3: CodeCommit にプッシュ

```bash
# ワークロードリポジトリのルートに移動
cd ../..

# 変更をコミット・プッシュ
git add .
git commit -m "Add distribution-monitor application"
git push
```

### ステップ4: Argo CD でデプロイを確認

1. Argo CD UI にアクセス
2. 数秒～数分後、`workloads-ex-app-distribution-monitor-dev` Application が自動的に作成されます
3. Application をクリックして、リソースの同期状態を確認
4. すべてのリソースが Healthy になるまで待ちます

### ステップ5: アプリケーションへのアクセス

```bash
# Active 環境の URL を取得
kubectl get ingress -n ex-app distribution-monitor-active -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Preview 環境の URL を取得
kubectl get ingress -n ex-app distribution-monitor-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

ブラウザで Active 環境の URL にアクセスして、Distribution Monitor が動作していることを確認します。ページをリフレッシュするたびに、どの Pod が応答したかが記録され、負荷分散の状況が可視化されます。

### Blue/Green デプロイメントの動作確認

#### 新しいバージョンのデプロイ

1. アプリケーションコードを変更してイメージを更新：

```bash
cd apps/distribution-monitor
# コードを変更（例: src/main/resources/templates/index.html）
make build
make push

# 新しいイメージ情報を環境変数に更新
export IMAGE_TAG=$(make image-tag)
echo "New Image Tag: $IMAGE_TAG"
```

2. マニフェストを更新してプッシュ：

```bash
cd environments/sample/tmp/workloads/ex-app/distribution-monitor/base

# kustomization.yaml の newTag を新しいタグに更新
sed -i.bak "s/newTag: .*/newTag: ${IMAGE_TAG}/" kustomization.yaml

# 変更を確認
cat kustomization.yaml

# ワークロードリポジトリのルートに移動
cd ../..

git add .
git commit -m "Update distribution-monitor to new version ${IMAGE_TAG}"
git push
```

3. Argo CD が自動的に変更を検出し、新しいバージョンを Preview 環境にデプロイします

#### Rollout の操作

```bash
# Rollout の状態を確認
kubectl argo rollouts get rollout distribution-monitor -n ex-app

# Preview 環境の URL を取得して動作確認
kubectl get ingress -n ex-app distribution-monitor-preview -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 問題なければ、手動で Promote して Active 環境に切り替え
kubectl argo rollouts promote distribution-monitor -n ex-app

# Rollback が必要な場合
kubectl argo rollouts undo distribution-monitor -n ex-app
```

Argo CD UI でも Rollout の状態を視覚的に確認できます。Blue/Green デプロイメントにより、新しいバージョンを Preview 環境で確認してから、安全に本番環境（Active）に切り替えることができます。

詳細は [apps/distribution-monitor/README.md](apps/distribution-monitor/README.md) を参照してください。

## kro (Kubernetes Resource Orchestrator) によるワークロード抽象化

このプラットフォームは EKS Capability として [kro](https://kro.run/) をサポートしており、Developer の認知負荷を削減します。Platform Engineer が ResourceGraphDefinition (RGD) を定義することで、複雑なリソース構成をカスタム API として抽象化できます。

### 仕組み

```
Platform Engineer が RGD を定義        Developer が Instance を作成
（platform リポジトリに1回定義）        （workload リポジトリにアプリごと）
                                        
┌─────────────────────────┐            ┌─────────────────────┐
│ ResourceGraphDefinition │            │ WebApp Instance      │
│                         │            │                      │
│ WebApp API:             │            │ name: bg-demo        │
│   name, image,          │───────────▶│ image: my-app:v1     │
│   replicas, port,       │  利用      │ replicas: 2          │
│   ingressCidrs          │            │ ingressCidrs: x.x.x  │
└─────────────────────────┘            └─────────────────────┘
         │                                       │
         │ 定義                                  │ kro が検知
         ▼                                       ▼
┌─────────────────────────────────────────────────────────────┐
│ kro が自動生成:                                              │
│   • Rollout (Blue/Green)                                    │
│   • Service (active + preview)                              │
│   • Ingress (active + preview) + IP 制限                    │
└─────────────────────────────────────────────────────────────┘
```

### 2つのデプロイ方式

このリポジトリでは、同じアプリケーションを2つの方式でデプロイできます：

| 観点 | kro 版 | 従来版 |
|------|--------|--------|
| 配置場所 | `workloads/ex-app/bg-demo-kro/` | `workloads/ex-app/bg-demo-traditional/` |
| Developer が書くファイル数 | 1ファイル（WebApp Instance） | 5ファイル以上（Rollout, Service, Ingress, Kustomization） |
| 必要な K8s 知識 | WebApp の spec のみ | Rollout, Service, Ingress, Kustomize |
| 構成変更の全体反映 | RGD 更新で全 Instance に自動反映 | 各チームが個別に修正 |
| 前提条件 | kro Capability + RGD | Argo Rollouts のみ |

### kro 版でデプロイ

```bash
# kro 版で workload を push
./scripts/push-workload.sh kro
```

Developer が書くのはこれだけ：

```yaml
# webapp-instance.yaml
apiVersion: kro.run/v1alpha1
kind: WebApp
metadata:
  name: bg-demo
spec:
  name: bg-demo
  image: argoproj/rollouts-demo:blue
  replicas: 2
  port: 8080
  ingressCidrs: "x.x.x.x/32,y.y.y.y/32"
```

### 従来版でデプロイ

```bash
# 従来版で workload を push
./scripts/push-workload.sh traditional
```

Kustomize で base マニフェスト + dev overlay（IP 制限パッチ）を適用します。

### 新しい RGD の追加（Platform Engineer 向け）

1. `repositories/platform/config/kro-definitions/` に新しい RGD YAML を作成
2. `./scripts/push-platform.sh` で CodeCommit に push
3. ArgoCD が RGD を Sync → kro が新しい CRD を生成
4. Developer が新しいカスタム API を利用可能に

詳細な使い方は [repositories/workloads/README.md](repositories/workloads/README.md) を参照してください。

## ACK (AWS Controllers for Kubernetes) による AWS リソース管理

このプラットフォームでは、開発者が ACK (AWS Controllers for Kubernetes) を使用して、Kubernetes から直接 AWS リソースを作成・管理できます。プラットフォームチームが Namespace ごとに IAM 権限を付与することで、開発者は自分の Namespace 内で安全に AWS リソースを管理できます。

### プラットフォームチームによる Namespace への IAM 権限設定

プラットフォームチームは、`ack_iam_role_selector` Terraform モジュールを使用して、特定の Namespace に AWS サービスの権限を付与します。これにより、最小権限の原則に従い、Namespace ごとにスコープされた権限を付与できます。

#### 例: ex-app Namespace に S3 権限を付与

設定ファイルを作成します（例: `environments/sample/namespace_ex_app.tf`）：

```hcl
module "ack_iam_role_selector_ex_app_s3" {
  source = "../../modules/ack_iam_role_selector"

  resource_prefix          = var.resource_prefix
  environment              = "dev"
  selector_name            = "ex-app-s3"
  namespace                = "ex-app"
  ack_controller_role_arn  = module.cluster_development.ack_capability_role_arn
  namespace_selector_names = ["ex-app"]

  # 特定のバケットパターンに対する S3 権限
  iam_policy_statements = [
    {
      effect = "Allow"
      actions = [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucket*",
        "s3:PutBucket*",
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::ex-idp-dev-ex-app-*"
      ]
    },
    {
      effect = "Allow"
      actions = [
        "s3:ListAllMyBuckets"
      ]
      resources = ["*"]
    }
  ]
}
```

設定を適用します：

```bash
cd environments/sample
terraform apply
```

これにより以下が作成されます：
1. `ex-idp-dev-ex-app-*` パターンにマッチするバケットに対する S3 権限を持つ IAM ロール
2. そのロールを `ex-app` Namespace に関連付ける Kubernetes `IAMRoleSelector` CRD

### 開発者による ACK を使った AWS リソースの作成

プラットフォームチームが IAM 権限を設定した後、開発者は自分の Namespace に Kubernetes マニフェストを適用することで AWS リソースを作成できます。

#### 例: S3 バケットの作成

マニフェストファイルを作成します（例: `s3-bucket.yaml`）：

```yaml
apiVersion: s3.services.k8s.aws/v1alpha1
kind: Bucket
metadata:
  name: my-app-data
  namespace: ex-app
spec:
  name: ex-idp-dev-ex-app-my-app-data
```

マニフェストを適用します：

```bash
kubectl apply -f s3-bucket.yaml
```

バケットが作成されたことを確認します：

```bash
# Kubernetes リソースの状態を確認
kubectl get bucket -n ex-app my-app-data

# AWS で確認
aws s3 ls | grep ex-idp-dev-ex-app-my-app-data
```

ACK S3 controller は自動的に以下を実行します：
1. `ex-app` Namespace 用に設定された IAM ロールを assume
2. AWS に S3 バケットを作成
3. Kubernetes リソースのステータスをバケットの状態で更新

#### リソースの削除

```bash
kubectl delete bucket -n ex-app my-app-data
```

ACK は対応する AWS リソースを自動的に削除します。

### セキュリティモデル：責任共有モデル

このプラットフォームは、プラットフォームチームと開発チームの間で明確な責任分離を実現します：

**プラットフォームチームの責任**
- Namespace ごとの IAM 権限の設定と管理
- セキュリティポリシーの定義（どの AWS サービスへのアクセスを許可するか）
- リソース命名規則の強制（例: `ex-idp-dev-ex-app-*` パターン）
- 最小権限の原則に基づいた権限設計

**開発チームの責任**
- アプリケーションに必要な AWS リソースの作成と管理
- Kubernetes マニフェストによる宣言的なリソース定義
- アプリケーションライフサイクルに合わせたリソースの追加・削除

この分離により、開発チームは AWS IAM の複雑な設定を意識することなく、必要なリソースをセルフサービスで作成できます。一方、プラットフォームチームはセキュリティとガバナンスを一元管理できます。

### サポートされている AWS サービス

ACK は以下を含む多くの AWS サービスをサポートしています：
- S3 (Simple Storage Service)
- DynamoDB
- RDS (Relational Database Service)
- ElastiCache
- SNS/SQS
- その他多数

完全なリストは [ACK Service Controllers](https://aws-controllers-k8s.github.io/community/docs/community/services/) を参照してください。

## 主要な機能

### EKS Capabilities - マネージド Argo CD
- **フルマネージド**: AWS が Argo CD のインストール、アップグレード、パッチ適用を自動管理
- **IAM Identity Center 統合**: SSO 認証が自動設定され、ユーザー管理が簡素化
- **高可用性**: AWS が HA 構成を自動管理
- **セキュリティ**: AWS のベストプラクティスに基づいた設定
- 詳細: [Amazon EKS Capabilities - Argo CD](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)

### GitOps による自動デプロイ
- Git リポジトリへの push で自動的にクラスターに反映
- ApplicationSet による動的な Application 生成
- 環境ごとの設定オーバーライド（Kustomize）

### マルチテナンシー
- Namespace ごとの分離とリソース制限
- Helm チャートによる標準化された設定
- 環境別の values ファイルによるカスタマイズ

### 高度なデプロイ戦略
- Argo Rollouts による Blue/Green デプロイメント
- 手動 Promotion による安全なリリース
- Rollback 機能

### 統合監視
- CloudWatch Container Insights
- Application Signals による自動計装
- Java、Python、.NET、Node.js アプリケーションのトレーシング

## カスタマイズ

### 新しい Namespace の追加

1. `repositories/platform/namespaces/` に新しいディレクトリを作成
2. `config/config.yaml` で Namespace 設定を定義
3. `workloads/` にワークロード ApplicationSet を配置
4. Git に push すると自動的にデプロイされます

### 新しいアドオンの追加

1. `repositories/platform/config/addons/` に ApplicationSet を作成
2. 環境別の values ファイルを配置
3. `config-addons.yaml` が自動的に検出してデプロイ

## トラブルシューティング

### EKS Capabilities - Argo CD の状態確認
```bash
# Capability の状態を確認
aws eks describe-capability \
  --cluster-name ex-idp-dev-cluster \
  --capability-name argocd

# Argo CD Pod の状態を確認
kubectl get pods -n argocd
```

マネージド版では、Argo CD 自体の運用は AWS が管理するため、コンポーネントの障害は AWS が自動的に対応します。

### ApplicationSet が Application を生成しない
```bash
kubectl get applicationset -n argocd
kubectl describe applicationset bootstrap -n argocd

# Cluster Secret の確認（ApplicationSet のジェネレーターで使用）
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster
```

### EKS Auto Mode のノードが起動しない
```bash
kubectl get nodeclaim
kubectl describe nodeclaim <nodeclaim-name>
```

## クリーンアップ

```bash
cd environments/sample
terraform destroy
```

## 参考資料

- [Amazon EKS Capabilities - Argo CD](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)
- [Amazon EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## ライセンス

このプロジェクトは MIT-0 ライセンスの下で公開されています。
