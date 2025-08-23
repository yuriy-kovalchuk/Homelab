helm repo add minio https://charts.min.io/
helm repo update
kubectl create namespace minio

helm install minio minio/minio \
  --namespace minio \
  --set accessKey=minioadmin \
  --set secretKey=minioadmin
