package models

// IngressInfo represents the relevant information from a Kubernetes Ingress
type IngressInfo struct {
	Name           string   // Name of the ingress
	Namespace      string   // Namespace of the ingress
	LoadBalancerIP string   // External IP or hostname of the load balancer
	Hostnames      []string // List of hostnames from ingress rules
}
