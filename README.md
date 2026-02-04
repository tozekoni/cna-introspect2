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

# Setup rest of infra
```bash
terraform init
## apply will output api gateway endpoint url
terraform apply
```


# insert claim data
```bash

curl --header "Content-Type: application/json" --request POST \
  --data @../mocks/claims.json \
  https://2rwm9ygzsb.execute-api.us-east-1.amazonaws.com/api/claims
  
```