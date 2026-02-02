provider "aws" {
  region = "us-east-1"
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

data "aws_eks_cluster" "tz_cluster_cna2" {
  name = "tz-cluster-cna2"
}

resource "aws_iam_role" "codebuild_role" {
  name = "claim-app-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "claim-app-codebuild-policy"
  role = aws_iam_role.codebuild_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:GetConnectionToken"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      }
    ]
  })
}

resource "aws_codebuild_project" "claim_app_build" {
  name          = "claim-app-build"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "us-east-1"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.claim-app.name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
  }

  source {
    type            = "CODEPIPELINE"
    # location        = "https://github.com/tozekoni/cna-introspect2.git"
    # git_clone_depth = 1
    buildspec       = "pipelines/buildspec.yml"
    #
    # auth {
    #   resource = aws_codestarconnections_connection.github.arn
    #   type     = "CODECONNECTIONS"
    # }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_iam_role" "codepipeline_role" {
  name = "claim-app-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "claim-app-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:*"
        ]
        Resource = aws_codebuild_project.claim_app_build.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection",
          "codestar-connections:GetConnection",
          "codestar-connections:GetConnectionToken"
        ]
        Resource = aws_codestarconnections_connection.github.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/codepipeline/claim-app-pipeline:*"
      },
      {
        Effect = "Allow"
        Action = [
          "inspector-scan:ScanSbom"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = aws_ecr_repository.claim-app.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = data.aws_eks_cluster.tz_cluster_cna2.arn
      }
    ]
  })
}

resource "aws_eks_access_entry" "codepipeline" {
  cluster_name  = data.aws_eks_cluster.tz_cluster_cna2.name
  principal_arn = aws_iam_role.codepipeline_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "codepipeline" {
  cluster_name  = data.aws_eks_cluster.tz_cluster_cna2.name
  principal_arn = aws_iam_role.codepipeline_role.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}

resource "aws_codepipeline" "claim_app_pipeline" {
  name     = "claim-app-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.codepipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "tozekoni/cna-introspect2"
        BranchName = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.claim_app_build.name
      }
    }
  }

  stage {
    name = "Scan"

    action {
      category = "Invoke"
      name     = "Scan"
      owner    = "AWS"
      provider = "InspectorScan"
      input_artifacts = ["build_output"]
      output_artifacts = ["scan_output"]
      version  = "1"

      configuration = {
        InspectorRunMode: "ECRImageScan"
        ECRRepositoryName: aws_ecr_repository.claim-app.name
        ImageTag: "latest"
      }
    }
  }

  stage {
    name = "DeployApp"

    action {
      category = "Deploy"
      name     = "DeployApp"
      owner    = "AWS"
      provider = "EKS"
      version  = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ClusterName  = data.aws_eks_cluster.tz_cluster_cna2.name
        ManifestFiles = "src/k8s/deployment.yaml"
        # EnvironmentVariables = jsonencode([
        #   {
        #     name  = "IMAGE_URI"
        #     value = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/${aws_ecr_repository.claim-app.name}:latest"
        #     type  = "PLAINTEXT"
        #   }
        # ])
        # Variables     = jsonencode({
        #   IMAGE_URI = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/${aws_ecr_repository.claim-app.name}:latest"
        # })
      }

    }
  }

}
