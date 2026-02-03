If tf apply fails, check github connection status, update and retry: 
https://us-east-1.console.aws.amazon.com/codesuite/settings/connections


# Create eks cluster
```bash 
eksctl create cluster -f iac/eks-cluster.yaml
```

# Create k8s service
```bash
kubectl apply -f k8s/service.yaml
```