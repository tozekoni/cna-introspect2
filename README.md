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
## set to value from terraform output
export GW_BASE_URL="<api-gateway-endpoint-url>"

curl --header "Content-Type: application/json" --request POST \
  --data @../mocks/claims.json \
  "${GW_BASE_URL}/api/claims"
  

curl --header "Content-Type: application/json" --request POST \
  --data @../mocks/notes.json \
  "${GW_BASE_URL}/api/claimNotes"
  
```

# invoke summarize endpoint
```bash
curl --header "Content-Type: application/json" --request POST -i \
  "${GW_BASE_URL}/api/claims/CLAIM001/summarize"
```