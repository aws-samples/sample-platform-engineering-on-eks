# Workload デプロイ方式の使い分け

このリポジトリでは、同じアプリ（bg-demo）を **kro 版** と **従来版** の2つの方式でデプロイできます。

## 構成

```
repositories/workloads/ex-app/
├── bg-demo-kro/           ← kro 版
│   └── dev/
│       ├── kustomization.yaml
│       └── webapp-instance.yaml(.example)
│
└── bg-demo-traditional/   ← 従来版（Kustomize + 生マニフェスト）
    ├── base/
    │   ├── rollouts.yaml
    │   ├── service.yaml
    │   ├── ingress.yaml
    │   └── kustomization.yaml
    └── dev/
        ├── kustomization.yaml
        └── ingress-cidrs.yaml(.example)
```

## 使い分け方

### kro 版でデプロイする場合

```bash
./scripts/push-workload.sh kro
```

Developer は `webapp-instance.yaml` の1ファイルだけ書けばよい:

```yaml
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

kro が Rollout / Service×2 / Ingress×2 を自動生成します。

### 従来版でデプロイする場合

```bash
./scripts/push-workload.sh traditional
```

Kustomize で base マニフェスト + dev overlay（IP制限パッチ）を適用します。
Developer は Rollout / Service / Ingress の各マニフェストを個別に管理します。

## 前提条件

- `terraform apply` 済み（EKS + ArgoCD + ACK + kro Capability）
- platform リポジトリが CodeCommit に push 済み（`./scripts/push-platform.sh`）
- kro 版を使う場合: platform リポジトリに RGD が含まれていること

## セットアップ手順

```bash
# 1. terraform.tfvars を作成（terraform.tfvars.example を参考）
cp environments/sample/terraform.tfvars.example environments/sample/terraform.tfvars
# → 実際の値を記入

# 2. Terraform apply
cd environments/sample
terraform init
terraform apply

# 3. platform リポジトリを push
./scripts/push-platform.sh

# 4. workload の実ファイルを作成（.example を参考）
# kro 版:
cp repositories/workloads/ex-app/bg-demo-kro/dev/webapp-instance.yaml.example \
   repositories/workloads/ex-app/bg-demo-kro/dev/webapp-instance.yaml
# → 実際のIPアドレスを記入

# 従来版:
cp repositories/workloads/ex-app/bg-demo-traditional/dev/ingress-cidrs.yaml.example \
   repositories/workloads/ex-app/bg-demo-traditional/dev/ingress-cidrs.yaml
# → 実際のIPアドレスを記入

# 5. workload を push（kro 版 or 従来版を選択）
./scripts/push-workload.sh kro
# or
./scripts/push-workload.sh traditional
```

## 比較

| 観点 | kro 版 | 従来版 |
|------|--------|--------|
| Developer が書くファイル数 | 1 | 5+ |
| 必要な K8s 知識 | WebApp spec のみ | Rollout, Service, Ingress, Kustomize |
| 構成変更の全体反映 | RGD 更新で自動反映 | 各チームが個別に修正 |
| 前提 | kro Capability + RGD が必要 | Argo Rollouts のみ |
| 成熟度 | alpha（EKS Capability） | 安定 |
