package main

import (
	"log"

	"ingress-hostname-exporter/pkg/k8s"
	"ingress-hostname-exporter/pkg/opnsense"
)

func main() {
	// Initialize OPNsense environment & HTTP client
	opnsense.InitEnv()
	opnsense.InitHTTPClient()

	// Initialize Kubernetes client
	clientset, err := k8s.GetClientset()
	if err != nil {
		log.Fatalf("Kubernetes client error: %v", err)
	}

	// Start watching ingress resources
	k8s.WatchIngresses(clientset)
}
