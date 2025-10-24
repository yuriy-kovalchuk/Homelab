package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

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

	// Create Istio client
	istioClientset, err := k8s.GetVersionedClientset()
	if err != nil {
		log.Fatalf("Kubernetes client error: %v", err)
	}
	// Start watching ingress resources
	go k8s.WatchIngresses(clientset)
	go k8s.WatchIstioGateways(istioClientset, clientset)

	// Wait for interrupt signal (Ctrl+C)
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down gracefully...")
}
