# Distribution Monitor

A Spring Boot application that visualizes load distribution across Kubernetes Pods.

## Features

- **Pod ID Tracking**: Retrieves Pod ID using Kubernetes Downward API
- **Version Management**: Embeds Git hash as application version
- **Cookie-based Aggregation**: No database required, stores request history in cookies
- **Rich UI**: Modern interface implemented with CSS only (no JavaScript)
- **Real-time Visualization**: Displays request distribution across Pods with progress bars

## Tech Stack

- Java 25 (Amazon Corretto)
- Spring Boot 3.5.9
- Thymeleaf
- Gradle
- Docker / Finch

## Build Instructions

### Local Development

```bash
cd apps/distribution-monitor
./gradlew bootRun
```

Access `http://localhost:8080` in your browser

### Build with Makefile

#### Show Help

```bash
make help
```

#### Build with Docker

```bash
make build
```

#### Build with Finch

```bash
make build RUNTIME=finch
```

#### Build for Specific Platform

```bash
# Build for amd64 only (for EKS Auto Mode)
make build PLATFORM=linux/amd64 RUNTIME=finch

# Build for arm64 only (for local development on Apple Silicon)
make build PLATFORM=linux/arm64 RUNTIME=finch

# Build for both platforms (default)
make build RUNTIME=finch
```

#### Run Locally

```bash
# Run with Docker
make run

# Run with Finch
make run RUNTIME=finch

# Stop
make stop
```

#### Push to ECR

```bash
# Auto-detect AWS account and region from AWS CLI configuration
make login
make push

# Override AWS account ID if needed
make login AWS_ACCOUNT_ID=123456789012
make push AWS_ACCOUNT_ID=123456789012

# Using Finch
make login RUNTIME=finch
make push RUNTIME=finch
```

Note: The `push` target automatically creates the ECR repository if it doesn't exist.
AWS Account ID and Region are automatically detected from your AWS CLI configuration.

#### Other Commands

```bash
# Show build information
make info

# Run Gradle tests
make test

# Remove local images
make clean
```

## Kubernetes Deployment

### Using Makefile (Recommended)

```bash
# Deploy with auto-detected AWS credentials
make deploy

# Check deployment status (includes Ingress URL)
make status

# View logs
make logs

# Remove deployment
make undeploy
```

The application is exposed via AWS Application Load Balancer (ALB) through Kubernetes Ingress.
After deployment, use `make status` to get the ALB hostname.

### Manual Deployment

1. Update the image URL in `k8s/deployment.yaml`:

```yaml
image: <account-id>.dkr.ecr.<region>.amazonaws.com/distribution-monitor:<git-hash>
```

2. Deploy:

```bash
kubectl apply -f k8s/deployment.yaml
```

3. Check service endpoint:

```bash
kubectl get ingress distribution-monitor
```

The application uses:
- 2 replicas for high availability
- ClusterIP service for internal communication
- AWS ALB Ingress Controller for external access

## Usage

1. Access the application in your browser
2. Each page refresh records which Pod responded
3. Request count and percentage for each Pod are displayed with progress bars
4. The currently responding Pod is highlighted
5. Click "Clear Data" button to clear cookies and reset statistics

## Makefile Targets

| Target | Description |
|--------|-------------|
| `help` | Show help message |
| `build` | Build container image |
| `tag` | Tag image for ECR |
| `login` | Login to ECR |
| `login-public` | Login to ECR Public |
| `create-repo` | Create ECR repository if it doesn't exist |
| `push` | Push image to ECR (auto-creates repo) |
| `run` | Run container locally |
| `stop` | Stop running container |
| `clean` | Remove local images |
| `deploy` | Deploy to Kubernetes |
| `undeploy` | Remove deployment from Kubernetes |
| `status` | Check deployment status |
| `logs` | Show logs from pods |
| `test` | Run Gradle tests |
| `gradle-build` | Run Gradle build |
| `info` | Show build information |

## Environment Variables

### Application

- `POD_ID`: Pod name automatically set by Kubernetes Downward API
- `app.version`: Version automatically set from Git hash during build

### Makefile

- `RUNTIME`: Container runtime (`docker` or `finch`, default: `docker`)
- `PLATFORM`: Target platform architecture (default: `linux/amd64,linux/arm64`)
  - `linux/amd64`: For x86_64 architecture (EKS Auto Mode)
  - `linux/arm64`: For ARM64 architecture (Apple Silicon, Graviton)
  - `linux/amd64,linux/arm64`: Multi-platform build
- `AWS_ACCOUNT_ID`: AWS Account ID (auto-detected from AWS CLI, can be overridden)
- `AWS_REGION`: AWS Region (auto-detected from AWS CLI, default: `ap-northeast-1`)

## Architecture

- Uses cookies to store request history on the client side
- Records current Pod ID and version in cookies for each request
- Server reads cookies and calculates statistics
- Dynamically generates HTML with Thymeleaf templates
- Rich UI achieved with CSS animations and gradients

---

# Distribution Monitor (日本語)

Kubernetes環境でのPod間の負荷分散状況を可視化するSpring Bootアプリケーションです。

## 特徴

- **Pod ID追跡**: Kubernetes Downward APIを使用してPod IDを取得
- **バージョン管理**: Gitハッシュをアプリケーションバージョンとして埋め込み
- **Cookieベース集計**: データベース不要、Cookieでリクエスト履歴を保存
- **リッチUI**: JavaScriptを使わず、CSSのみで実装されたモダンなインターフェース
- **リアルタイム可視化**: 各Podへのリクエスト分散状況をプログレスバーで表示

## 技術スタック

- Java 25 (Amazon Corretto)
- Spring Boot 3.5.9
- Thymeleaf
- Gradle
- Docker / Finch

## ビルド方法

### ローカル開発

```bash
cd apps/distribution-monitor
./gradlew bootRun
```

ブラウザで `http://localhost:8080` にアクセス

### Makefileを使用したビルド

#### ヘルプの表示

```bash
make help
```

#### Dockerでビルド

```bash
make build
```

#### Finchでビルド

```bash
make build RUNTIME=finch
```

#### 特定のプラットフォーム向けビルド

```bash
# amd64のみビルド（EKS Auto Mode用）
make build PLATFORM=linux/amd64 RUNTIME=finch

# arm64のみビルド（Apple Siliconでのローカル開発用）
make build PLATFORM=linux/arm64 RUNTIME=finch

# 両プラットフォーム向けビルド（デフォルト）
make build RUNTIME=finch
```

#### ローカルで実行

```bash
# Dockerで実行
make run

# Finchで実行
make run RUNTIME=finch

# 停止
make stop
```

#### ECRへのプッシュ

```bash
# AWS CLIの設定からAWSアカウントとリージョンを自動検出
make login
make push

# 必要に応じてAWSアカウントIDを上書き
make login AWS_ACCOUNT_ID=123456789012
make push AWS_ACCOUNT_ID=123456789012

# Finchを使用
make login RUNTIME=finch
make push RUNTIME=finch
```

注: `push`ターゲットは、ECRリポジトリが存在しない場合は自動的に作成します。
AWSアカウントIDとリージョンは、AWS CLIの設定から自動検出されます。

#### その他のコマンド

```bash
# ビルド情報を表示
make info

# Gradleテストを実行
make test

# ローカルイメージを削除
make clean
```

## Kubernetesへのデプロイ

### Makefileを使用（推奨）

```bash
# AWS認証情報を自動検出してデプロイ
make deploy

# デプロイ状況を確認（Ingress URLを含む）
make status

# ログを表示
make logs

# デプロイを削除
make undeploy
```

アプリケーションはKubernetes IngressとAWS Application Load Balancer (ALB)を通じて公開されます。
デプロイ後、`make status`でALBのホスト名を取得できます。

### 手動デプロイ

1. `k8s/deployment.yaml` のイメージURLを更新:

```yaml
image: <account-id>.dkr.ecr.<region>.amazonaws.com/distribution-monitor:<git-hash>
```

2. デプロイ:

```bash
kubectl apply -f k8s/deployment.yaml
```

3. サービスのエンドポイントを確認:

```bash
kubectl get ingress distribution-monitor
```

アプリケーションの構成:
- 高可用性のため2レプリカ
- 内部通信用のClusterIPサービス
- 外部アクセス用のAWS ALB Ingress Controller

## 使い方

1. ブラウザでアプリケーションにアクセス
2. ページをリフレッシュするたびに、どのPodが応答したかが記録されます
3. 各Podへのリクエスト数と割合がプログレスバーで表示されます
4. 現在応答したPodは強調表示されます
5. 「Clear Data」ボタンでCookieをクリアし、統計をリセットできます

## Makefileターゲット一覧

| ターゲット | 説明 |
|-----------|------|
| `help` | ヘルプを表示 |
| `build` | コンテナイメージをビルド |
| `tag` | ECR用にイメージをタグ付け |
| `login` | ECRにログイン |
| `login-public` | ECR Publicにログイン |
| `create-repo` | ECRリポジトリが存在しない場合は作成 |
| `push` | イメージをECRにプッシュ（リポジトリ自動作成） |
| `run` | ローカルでコンテナを実行 |
| `stop` | 実行中のコンテナを停止 |
| `clean` | ローカルイメージを削除 |
| `deploy` | Kubernetesにデプロイ |
| `undeploy` | Kubernetesからデプロイを削除 |
| `status` | デプロイ状況を確認 |
| `logs` | Podのログを表示 |
| `test` | Gradleテストを実行 |
| `gradle-build` | Gradleビルドを実行 |
| `info` | ビルド情報を表示 |

## 環境変数

### アプリケーション

- `POD_ID`: Kubernetes Downward APIから自動設定されるPod名
- `app.version`: ビルド時にGitハッシュから自動設定されるバージョン

### Makefile

- `RUNTIME`: コンテナランタイム（`docker` または `finch`、デフォルト: `docker`）
- `PLATFORM`: ターゲットプラットフォームアーキテクチャ（デフォルト: `linux/amd64,linux/arm64`）
  - `linux/amd64`: x86_64アーキテクチャ用（EKS Auto Mode）
  - `linux/arm64`: ARM64アーキテクチャ用（Apple Silicon、Graviton）
  - `linux/amd64,linux/arm64`: マルチプラットフォームビルド
- `AWS_ACCOUNT_ID`: AWSアカウントID（AWS CLIから自動検出、上書き可能）
- `AWS_REGION`: AWSリージョン（AWS CLIから自動検出、デフォルト: `ap-northeast-1`）

## アーキテクチャ

- Cookieを使用してクライアント側でリクエスト履歴を保存
- 各リクエストで現在のPod IDとバージョンをCookieに記録
- サーバー側でCookieを読み取り、統計情報を計算
- Thymeleafテンプレートで動的にHTMLを生成
- CSSアニメーションとグラデーションでリッチなUIを実現
