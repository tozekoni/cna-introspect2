provider "aws" {
  region = var.region
}

locals {
  vpc_id = data.aws_eks_cluster.this.vpc_config[0].vpc_id
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = ["false"]
  }
}

data "aws_lb" "eks_nlb" {
  tags = {
    "kubernetes.io/service-name" = "default/${var.service_name}"
  }
}

resource "aws_ecr_repository" "claim-app" {
  name                 = "claim-app"
  image_tag_mutability = "MUTABLE"
}

resource "aws_s3_bucket" "claim_notes" {
  bucket        = "claim-notes-bucket"
  force_destroy = true
}

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket        = "claim-notes-codepipeline-artifacts-${random_id.suffix.hex}"
  force_destroy = true
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_lb_listener" "eks" {
  load_balancer_arn = data.aws_lb.eks_nlb.arn
  port              = 80
}

resource "aws_dynamodb_table" "claims" {
  name         = "claims-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "policyNumber"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  global_secondary_index {
    name            = "policyNumber-index"
    hash_key        = "policyNumber"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "status-index"
    hash_key        = "status"
    projection_type = "ALL"
  }
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_policy" "pod_access_policy" {
  name = "eks-pod-to-services-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.claims.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.claim_notes.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/amazon.nova-pro-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "pod_identity_role" {
  name = "eks-pod-identity-s3-dynamo"

  # Simplified Trust Policy for Pod Identity
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession" # Required for Pod Identity
        ]
      }
    ]
  })
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

resource "aws_iam_role_policy_attachment" "attach_s3_dynamo" {
  role       = aws_iam_role.pod_identity_role.name
  policy_arn = aws_iam_policy.pod_access_policy.arn # From the previous step
}

resource "aws_eks_pod_identity_association" "pod_identity_assoc" {
  cluster_name    = data.aws_eks_cluster.this.name
  namespace       = "default"
  service_account = "claims-app-sa"
  role_arn        = aws_iam_role.pod_identity_role.arn
}

resource "kubernetes_service_account_v1" "claims_app_sa" {
  metadata {
    name      = "claims-app-sa"
    namespace = "default"

  }
}
