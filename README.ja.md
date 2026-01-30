# プラットフォームエンジニアリング リファレンスアーキテクチャ (Amazon EKS 利用)

> このリポジトリは、教育およびデモンストレーション目的のリファレンス実装を提供します。追加のセキュリティテスト、強化、検証なしにそのまま本番環境にデプロイしないでください。

Amazon EKS と Argo CD を活用した Platform Engineering のリファレンス実装です。GitOps ベースの宣言的なインフラ管理と、開発者向けのセルフサービス型プラットフォームを実現します。

## 概要

このプロジェクトは、以下の要素で構成される Internal Developer Platform (IDP) のデモンストレーションです：

- **EKS Auto Mode**: マネージド型の Kubernetes クラスター（コンピュートとストレージの自動管理）
- **EKS Capabilities - Argo CD**: AWS がフルマネージドで提供する Argo CD（インストール・アップグレード・運用を AWS が管理）
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
│   │   ├── config/             # アドオン設定（Argo Rollouts など）
│   │   └── namespaces/         # Namespace 定義とワークロード設定
│   └── workloads/              # アプリケーションマニフェストリポジトリ
│       └── bg-demo/            # Blue/Green デプロイメントデモ
└── apps/
    └── distribution-monitor/    # サンプルアプリケーション（負荷分散可視化）
```

### コンポーネント

#### 1. Platform Cluster Module
Terraform で EKS クラスターを構築します：
- **EKS Auto Mode**: ノードとストレージの自動管理
- **VPC**: 3 AZ 構成のプライベートネットワーク
- **EKS Capabilities - Argo CD**: AWS フルマネージド版 Argo CD（自動インストール・アップグレード）
- **CloudWatch Observability**: Application Signals による統合監視
- **IAM Identity Center**: Argo CD の SSO 認証（マネージド版の組み込み機能）

#### 2. GitOps ブートストラップ
Argo CD ApplicationSet による階層的な自動デプロイ：

```
bootstrap (Root ApplicationSet)
├── bootstrap-namespaces    # Namespace 設定の自動検出とデプロイ
├── bootstrap-workloads     # ワークロードの自動検出とデプロイ
├── config-addons          # クラスターアドオン（Argo Rollouts など）
└── config-automode        # EKS Auto Mode 設定
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
