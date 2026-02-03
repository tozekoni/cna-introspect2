provider "aws" {
  region = var.region
}

locals {
  vpc_id = data.aws_eks_cluster.tz_cluster_cna2.vpc_config[0].vpc_id
}

data "aws_eks_cluster" "tz_cluster_cna2" {
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

resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "eks-vpc-link"
  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = []
}


resource "aws_ecr_repository" "claim-app" {
  name                 = "claim-app"
  image_tag_mutability = "MUTABLE"
}

resource "aws_s3_bucket" "claim_notes" {
  bucket        = "claim-notes-bucket-${random_id.suffix.hex}"
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

resource "aws_apigatewayv2_api" "api_gw" {
  name          = "claim-app-api-gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "eks" {
  api_id           = aws_apigatewayv2_api.api_gw.id
  integration_type = "HTTP_PROXY"

  connection_type = "VPC_LINK"
  connection_id   = aws_apigatewayv2_vpc_link.eks.id

  integration_method = "ANY"
  integration_uri    = data.aws_lb_listener.eks.arn
}

resource "aws_apigatewayv2_route" "api" {
  api_id    = aws_apigatewayv2_api.api_gw.id
  route_key = "ANY /api/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api_gw.id
  name        = "$default"
  auto_deploy = true
}