# CI/CD Pipeline

This directory contains the build specification for the Claims Service CI/CD pipeline.

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Pipeline Stages](#-pipeline-stages)
- [Build Specification](#-build-specification)
- [Environment Variables](#️-environment-variables)
- [Infrastructure Reference](#️-infrastructure-reference)
- [IAM Permissions](#-iam-permissions)
- [Manual Trigger](#-manual-trigger)
- [Monitoring](#-monitoring)
- [Troubleshooting](#️-troubleshooting)

---

## 📋 Overview

The Claims Service uses **AWS CodePipeline** with **AWS CodeBuild** to automate the build, scan, and deployment process. The pipeline is triggered automatically on every push to the `main` branch.

---

## 🔄 Pipeline Stages

```
┌──────────┐     ┌───────────┐     ┌───────────┐     ┌────────────┐
│  Source  │────▶│  Build    │────▶│   Scan    │────▶│ DeployApp  │
│ (GitHub) │     │(CodeBuild)│     │(Inspector)│     │   (EKS)    │
└──────────┘     └───────────┘     └───────────┘     └────────────┘
```

### Stage 1: Source
- **Provider**: CodeStar Source Connection (GitHub)
- **Repository**: `tozekoni/cna-introspect2`
- **Branch**: `main`
- **Trigger**: Automatic on push

### Stage 2: Build
- **Provider**: AWS CodeBuild
- **Project**: `claim-app-build`
- **BuildSpec**: `pipelines/buildspec.yml`
- **Actions**:
  1. Login to Amazon ECR
  2. Build Docker image from `src/Dockerfile`
  3. Tag image with commit hash and `latest`
  4. Push images to ECR
  5. Generate Kubernetes deployment manifest

### Stage 3: Scan
- **Provider**: Amazon Inspector
- **Mode**: ECR Image Scan
- **Purpose**: Security vulnerability scanning of the container image

### Stage 4: DeployApp
- **Provider**: AWS EKS
- **Cluster**: `claims-eks-cluster`
- **Manifest**: `dist/deployment.yaml` (generated during build)

---

## 📄 Build Specification

### `buildspec.yml`

The build specification defines three phases:

#### Pre-Build Phase
```yaml
- Authenticate with Amazon ECR
- Set repository URI and image tag (using commit hash)
```

#### Build Phase
```yaml
- Navigate to src/ directory
- Build Docker image
- Tag with latest and commit hash
- Generate deployment.yaml with image URL substitution
```

#### Post-Build Phase
```yaml
- Push Docker images to ECR
- Generate imagedefinitions.json for deployment
```

### Build Artifacts

| Artifact | Description |
|----------|-------------|
| `src/imagedefinitions.json` | Container image definition for EKS |
| `dist/deployment.yaml` | Kubernetes deployment manifest with image URL |

---

## 🛠️ Environment Variables

The following environment variables are configured in CodeBuild:

| Variable | Description |
|----------|-------------|
| `AWS_ACCOUNT_ID` | AWS account ID (auto-populated) |
| `AWS_DEFAULT_REGION` | AWS region (`us-east-1`) |
| `IMAGE_REPO_NAME` | ECR repository name (`claim-app`) |
| `IMAGE_TAG` | Default image tag (`latest`) |

---

## 🏗️ Infrastructure Reference

The CodePipeline and CodeBuild infrastructure is defined in Terraform:

📁 **[`../iac/pipeline.tf`](../iac/pipeline.tf)**

### Resources Created

| Resource | Type | Purpose |
|----------|------|---------|
| `aws_codepipeline.claim_app_pipeline` | CodePipeline | Main CI/CD pipeline |
| `aws_codebuild_project.claim_app_build` | CodeBuild Project | Docker build & push |
| `aws_codestarconnections_connection.github` | CodeStar Connection | GitHub integration |
| `aws_iam_role.codepipeline_role` | IAM Role | Pipeline execution role |
| `aws_iam_role.codebuild_role` | IAM Role | Build execution role |
| `aws_s3_bucket.codepipeline_artifacts` | S3 Bucket | Pipeline artifact storage |
| `aws_eks_access_entry.codepipeline` | EKS Access Entry | Pipeline access to EKS |

---

## 🔐 IAM Permissions

### CodeBuild Role Permissions
- ECR: Full access (push/pull images)
- CloudWatch Logs: Create and write logs
- S3: Read/write pipeline artifacts
- CodeStar Connections: Use GitHub connection

### CodePipeline Role Permissions
- CodeBuild: Start and manage builds
- S3: Read/write pipeline artifacts
- CodeStar Connections: Access GitHub
- ECR: Pull images
- EKS: Describe and deploy to cluster
- Inspector: Run security scans

---

## 🚀 Manual Trigger

To manually trigger the pipeline via AWS CLI:

```bash
aws codepipeline start-pipeline-execution --name claim-app-pipeline
```

---

## 📊 Monitoring

View pipeline execution in the AWS Console:

- **CodePipeline**: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/claim-app-pipeline
- **CodeBuild**: https://console.aws.amazon.com/codesuite/codebuild/projects/claim-app-build
- **Build Logs**: CloudWatch Logs `/aws/codebuild/claim-app-build`

---

## ⚠️ Troubleshooting

### GitHub Connection Issues
If the pipeline fails at the Source stage, verify the GitHub connection is active:
https://us-east-1.console.aws.amazon.com/codesuite/settings/connections

### Build Failures
Check CodeBuild logs for detailed error messages:
```bash
aws logs get-log-events \
  --log-group-name /aws/codebuild/claim-app-build \
  --log-stream-name <build-id>
```

### Deployment Failures
Verify EKS access and cluster health:
```bash
kubectl get pods -n default
kubectl describe deployment claim-service-deployment
```
