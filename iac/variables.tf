variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "claims-eks-cluster"
}

variable "service_name" {
  description = "Kubernetes Service exposing the API"
  default = "claim-service"
}