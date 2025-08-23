helm install tempo grafana/tempo \
  --namespace tempo \
  --set tempo.distributor.receivers.otlp.protocols.grpc=true \
  --set tempo.distributor.receivers.otlp.protocols.http=true
