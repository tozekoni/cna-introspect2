variable "region" {
  default = "us-east-1"
}

variable "cluster_name" {
  default = "tz-cluster-cna2"
}

variable "service_name" {
  description = "Kubernetes Service exposing the API"
  default = "claim-service"
}