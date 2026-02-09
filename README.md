# CNA Introspect - Claims Service

An AI-powered insurance claims processing service that leverages AWS Bedrock (Amazon Nova Pro) to generate intelligent claim summaries. Built on AWS EKS with a fully automated CI/CD pipeline.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Architecture Reasoning & Trade-offs](#architecture-reasoning--trade-offs)
- [Architecture Diagram](#architecture-diagram)
- [Infrastructure Components](#infrastructure-components)
- [Node.js Service Details](#nodejs-service-details)
- [API Endpoints](#api-endpoints)
- [Setup Instructions](#setup-instructions)
- [Usage Examples](#usage-examples)

---

## 🏗️ Architecture Overview

The Claims Service is a cloud-native application deployed on AWS with the following key characteristics:

- **Compute**: Kubernetes workloads running on Amazon EKS
- **AI/ML**: Amazon Bedrock with Nova Pro model for intelligent claim summarization
- **Data Storage**: DynamoDB for claims data, S3 for claim notes
- **API Gateway**: AWS API Gateway (HTTP API) with VPC Link integration
- **Observability**: AWS X-Ray tracing, CloudWatch metrics & dashboards
- **CI/CD**: AWS CodePipeline with CodeBuild for automated deployments

---

## 🤔 Architecture Reasoning & Trade-offs

### Why EKS over ECS or Lambda?

| Factor | EKS | ECS | Lambda |
|--------|-----|-----|--------|
| **Container orchestration** | Full Kubernetes flexibility | AWS-native simplicity | No container management |
| **Portability** | Multi-cloud compatible | AWS-locked | AWS-locked |
| **Cold starts** | None | None | Significant for Node.js |
| **Operational complexity** | Higher | Medium | Lower |

**Decision**: EKS was chosen for Kubernetes portability, advanced scheduling, and long-running workloads that benefit from persistent containers (no cold starts for AI summarization requests).

### Why DynamoDB + S3 over RDS?

| Aspect | DynamoDB + S3 | RDS (PostgreSQL) |
|--------|---------------|------------------|
| **Scalability** | Automatic, serverless | Manual scaling required |
| **Cost model** | Pay-per-request | Always-on instance costs |
| **Claim notes storage** | S3 optimized for large JSON documents | JSONB column, limited size |
| **Operational overhead** | Near zero | Backups, patching, failover |

**Decision**: Claims metadata fits DynamoDB's key-value access patterns. Large claim notes (potentially MB-sized) are better suited for S3 with cheap storage and direct access.

### Why API Gateway HTTP API over ALB?

| Feature | HTTP API | ALB |
|---------|----------|-----|
| **Cost** | ~70% cheaper than REST API | Per-hour + LCU charges |
| **Latency** | Lower latency | Higher latency |
| **Features** | JWT auth, throttling, CORS | Full L7 features |
| **VPC integration** | VPC Link required | Native |

**Decision**: HTTP API provides cost-effective external access with built-in throttling (5000 burst/10000 rate). VPC Link ensures secure private connectivity to EKS NLB.

### Potential Improvements

| Current State | Future Consideration |
|---------------|---------------------|
| Single region deployment | Multi-region with Route 53 failover |
| Synchronous AI summarization | Async processing with SQS for large batches |
| Basic health checks | Liveness/readiness probes with circuit breakers |
| 2 replicas fixed | Horizontal Pod Autoscaler based on CPU/memory |
| CloudWatch only | Consider OpenTelemetry for vendor-neutral observability |

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                                     AWS Cloud                                       │
│                                                                                     │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────────────────────────────┐   │
│  │   GitHub     │────▶│ CodePipeline │────▶│           CodeBuild                │   │
│  │   Repo       │     │              │     │  (Build & Deploy to EKS)           │   │
│  └──────────────┘     └──────────────┘     └────────────────────────────────────┘   │
│                                                           │                         │
│                                                           ▼                         │
│  ┌──────────────┐     ┌──────────────┐     ┌────────────────────────────────────┐   │
│  │   Client     │────▶│ API Gateway  │────▶│              VPC                   │   │
│  │              │     │  (HTTP API)  │     │  ┌─────────────────────────────┐   │   │
│  └──────────────┘     └──────────────┘     │  │         EKS Cluster         │   │   │
│                              │             │  │  ┌─────────────────────┐    │   │   │
│                              │ VPC Link    │  │  │   Claims Service    │    │   │   │
│                              └─────────────│──│  │   (Node.js/Express) │    │   │   │
│                                            │  │  │   - 2 replicas      │    │   │   │
│                                            │  │  └─────────────────────┘    │   │   │
│                                            │  │             │               │   │   │
│                                            │  │     Network Load Balancer   │   │   │
│                                            │  └─────────────────────────────┘   │   │
│                                            └────────────────────────────────────┘   │
│                                                           │                         │
│                    ┌──────────────────────────────────────┼──────────────────┐      │
│                    │                                      │                  │      │
│                    ▼                                      ▼                  ▼      │
│  ┌─────────────────────┐     ┌─────────────────────┐    ┌────────────────────┐      │
│  │      DynamoDB       │     │         S3          │    │   Amazon Bedrock   │      │
│  │   (claims-table)    │     │  (claim-notes-      │    │   (Nova Pro v1)    │      │
│  │                     │     │      bucket)        │    │                    │      │
│  └─────────────────────┘     └─────────────────────┘    └────────────────────┘      │
│                                                                                     │
│  ┌──────────────────────────────────────────────────────────────────────────────┐   │
│  │                           Observability                                      │   │
│  │   ┌─────────────┐    ┌─────────────────┐    ┌────────────────────────────┐   │   │
│  │   │   X-Ray     │    │   CloudWatch    │    │   CloudWatch Dashboard     │   │   │
│  │   │  Tracing    │    │     Logs        │    │   (claims-app-dashboard)   │   │   │
│  │   └─────────────┘    └─────────────────┘    └────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                     │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🏢 Infrastructure Components

### Kubernetes (EKS)

| Component | Description |
|-----------|-------------|
| **Cluster** | `claims-eks-cluster` running Kubernetes v1.34 |
| **Node Group** | 2 t3.medium instances (auto-scaling 1-3) with private networking |
| **Service Account** | `claims-app-sa` with EKS Pod Identity for AWS service access |
| **Deployment** | 2 replicas with 300Mi memory, 250m CPU requests |
| **Service** | Network Load Balancer (NLB) exposing port 80 → 3000 |

### EKS Add-ons

- `eks-pod-identity-agent` - AWS service authentication
- `vpc-cni` - Kubernetes networking
- `coredns` - DNS resolution
- `kube-proxy` - Network proxy
- `aws-ebs-csi-driver` - EBS volume support
- `amazon-cloudwatch-observability` - Container insights

### Storage

| Service | Resource | Purpose |
|---------|----------|---------|
| **DynamoDB** | `claims-table` | Stores claim records with GSI on `policyNumber` and `status` |
| **S3** | `claim-notes-bucket` | Stores claim notes as JSON files (`claim/{claimId}/notes.json`) |
| **ECR** | `claim-app` | Docker image repository |

### API Gateway

| Property | Value |
|----------|-------|
| **Type** | HTTP API (v2) |
| **Integration** | VPC Link to EKS NLB |
| **Route** | `ANY /api/{proxy+}` |
| **Throttling** | 5000 burst / 10000 rate limit |
| **Logging** | CloudWatch with detailed request/response logging |

### AI/ML

| Service | Model | Purpose |
|---------|-------|---------|
| **Amazon Bedrock** | `amazon.nova-pro-v1:0` | Generates AI-powered claim summaries |

### CI/CD Pipeline

- **Source**: GitHub (via CodeStar Connections)
- **Build**: AWS CodeBuild (Docker build & push to ECR)
- **Deploy**: Automated deployment to EKS
- **Artifacts**: S3 bucket for pipeline artifacts

### Observability

| Component | Description |
|-----------|-------------|
| **AWS X-Ray** | Distributed tracing across all requests |
| **CloudWatch Metrics** | Custom `RequestDuration` metrics by endpoint/method/status |
| **CloudWatch Dashboard** | `claims-app-dashboard` with API response times, error rates, logs |
| **CloudWatch Logs** | API Gateway access logs, EKS application logs |

---

## 🖥️ Node.js Service Details

### Technology Stack

| Technology | Version | Purpose |
|------------|---------|---------|
| **Node.js** | 20 (Alpine) | Runtime |
| **Express.js** | 4.18.2 | Web framework |
| **AWS SDK v3** | 3.982.0 | AWS service clients |
| **AWS X-Ray SDK** | 3.12.0 | Distributed tracing |

### AWS SDK Clients Used

- `@aws-sdk/client-bedrock-runtime` - AI model invocation
- `@aws-sdk/client-dynamodb` / `@aws-sdk/lib-dynamodb` - Database operations
- `@aws-sdk/client-s3` - Object storage
- `@aws-sdk/client-cloudwatch` - Custom metrics

### Configuration

```javascript
REGION = 'us-east-1'
MODEL_ID = 'amazon.nova-pro-v1:0'
BUCKET_NAME = 'claim-notes-bucket'
```

### Service Features

- **CORS enabled** - Cross-origin requests supported
- **Async error handling** - Using `express-async-handler`
- **Request metrics** - Duration tracked per endpoint/method/status
- **Health checks** - Built-in `/health` endpoint

---

## 🔌 API Endpoints

### Health Check

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Returns service health status |

**Response:**
```json
{
  "status": "OK",
  "service": "claims-service",
  "timestamp": "2026-02-06T12:00:00.000Z"
}
```

### Claims API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/claims/:id` | Retrieve a claim by ID |
| `POST` | `/api/claims` | Batch insert claims |
| `POST` | `/api/claims/:id/summarize` | Generate AI summary for a claim |

### Claim Notes API

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/claimNotes` | Upload claim notes to S3 |

### Request/Response Examples

#### Get Claim
```bash
GET /api/claims/CLAIM001
```
**Response:**
```json
{
  "id": "CLAIM001",
  "policyNumber": "POL123456",
  "status": "submitted",
  "claimant": "Alice Smith",
  "dateFiled": "2024-05-01",
  "amount": 1200.50
}
```

#### Summarize Claim (AI-Powered)
```bash
POST /api/claims/CLAIM001/summarize
```
**Response:**
```json
{
  "overallSummary": "...",
  "customerFacingSummary": "...",
  "adjusterFocusedSummary": "...",
  "recommendedNextStep": "..."
}
```

---

## 🚀 Setup Instructions

### Prerequisites

- AWS CLI configured with appropriate credentials
- `eksctl` installed
- `kubectl` installed
- Terraform installed
- GitHub connection set up in AWS CodeStar

> **Note**: If `terraform apply` fails, check GitHub connection status and update:  
> https://us-east-1.console.aws.amazon.com/codesuite/settings/connections

### 1. Create EKS Cluster

```bash
eksctl create cluster -f iac/eks-cluster.yaml
```

### 2. Create Kubernetes Service

```bash
kubectl apply -f iac/k8s/service.yaml
```

### 3. Deploy Infrastructure with Terraform

```bash
cd iac
terraform init
terraform apply
# Note: This will output the API Gateway endpoint URL
```

---

## 📝 Usage Examples

### Set API Gateway URL

```bash
# Set to value from terraform output
export GW_BASE_URL="<api-gateway-endpoint-url>"
```

### Insert Claim Data

```bash
curl --header "Content-Type: application/json" --request POST \
  --data @mocks/claims.json \
  "${GW_BASE_URL}/api/claims"
```

### Upload Claim Notes

```bash
curl --header "Content-Type: application/json" --request POST \
  --data @mocks/notes.json \
  "${GW_BASE_URL}/api/claimNotes"
```

### Generate AI Claim Summary

```bash
curl --header "Content-Type: application/json" --request POST -i \
  "${GW_BASE_URL}/api/claims/CLAIM001/summarize"
```

---

## 🔐 IAM Permissions

The service uses EKS Pod Identity with the following permissions:

- **DynamoDB**: GetItem, PutItem, UpdateItem, BatchWriteItem, Query, Scan
- **S3**: GetObject, PutObject (on claim-notes-bucket)
- **Bedrock**: InvokeModel, InvokeModelWithResponseStream (Nova Pro models)
- **CloudWatch**: PutMetricData, log operations
- **X-Ray**: PutTraceSegments, PutTelemetryRecords
