package k8s

import (
	"context"
	"log"
	"os"
	"path/filepath"

	networkingv1 "k8s.io/api/networking/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"

	"ingress-hostname-exporter/internal/models"

	networkingv1beta1 "istio.io/client-go/pkg/apis/networking/v1beta1"
	versionedclient "istio.io/client-go/pkg/clientset/versioned"
)

import "ingress-hostname-exporter/pkg/opnsense"


// GetClientset returns a Kubernetes client
func GetClientset() (*kubernetes.Clientset, error) {
	if config, err := rest.InClusterConfig(); err == nil {
		return kubernetes.NewForConfig(config)
	}

	kubeconfig := filepath.Join(homeDir(), ".kube", "config")
	config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
	if err != nil {
		return nil, err
	}
	return kubernetes.NewForConfig(config)
}

func GetVersionedClientset() (*versionedclient.Clientset, error) {
	// Try in-cluster config first, then fall back to kubeconfig
	config, err := rest.InClusterConfig()
	if err != nil {
		kubeconfig := filepath.Join(os.Getenv("HOME"), ".kube", "config")
		config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
		if err != nil {
			log.Fatalf("Failed to get kubeconfig: %v", err)
		}
	}

	// Create Istio client
	istioClient, err := versionedclient.NewForConfig(config)
	if err != nil {
		log.Fatalf("Failed to create Istio client: %v", err)
	}
	return istioClient, err
}

func homeDir() string {
	home, err := os.UserHomeDir()
	if err != nil {
		// fallback to "/" if the home directory cannot be determined
		return "/"
	}
	return home
}


// WatchIngresses watches all ingress resources
func WatchIngresses(clientset *kubernetes.Clientset) {
	for {
		watcher, err := clientset.NetworkingV1().Ingresses("").Watch(context.TODO(), metav1.ListOptions{})
		if err != nil {
			log.Printf("Watch error: %v", err)
			continue
		}

		log.Println("Watching ingress resources...")
		for event := range watcher.ResultChan() {
			ingress, ok := event.Object.(*networkingv1.Ingress)
			if !ok {
				continue
			}

			info := CreateIngressInfo(ingress)
			for _, hostname := range info.Hostnames {
				if err := opnsense.ProcessIngress(info, hostname); err != nil {
					log.Printf("Failed for %s: %v", hostname, err)
				}
			}
		}
	}
}

// CreateIngressInfo converts a Kubernetes ingress to our model
func CreateIngressInfo(ingress *networkingv1.Ingress) models.IngressInfo {
	info := models.IngressInfo{
		Name:      ingress.Name,
		Namespace: ingress.Namespace,
	}

	if len(ingress.Status.LoadBalancer.Ingress) > 0 {
		lb := ingress.Status.LoadBalancer.Ingress[0]
		if lb.IP != "" {
			info.LoadBalancerIP = lb.IP
		} else {
			info.LoadBalancerIP = lb.Hostname
		}
	}

	for _, rule := range ingress.Spec.Rules {
		if rule.Host != "" {
			info.Hostnames = append(info.Hostnames, rule.Host)
		}
	}

	return info
}

func WatchIstioGateways(istioClient *versionedclient.Clientset, clientset *kubernetes.Clientset) {
	for {
		watcher, err := istioClient.NetworkingV1beta1().Gateways("").Watch(context.TODO(), metav1.ListOptions{})
		if err != nil {
			log.Printf("Watch error: %v", err)
			continue
		}

		log.Println("Watching Istio Gateway resources...")

		for event := range watcher.ResultChan() {
			gateway, ok := event.Object.(*networkingv1beta1.Gateway)
			if !ok {
				continue
			}

			info := CreateGatewayInfo(gateway, clientset)
			log.Printf("Gateway event: %s/%s with %d hosts and %d IPs",
				info.Namespace, info.Name, len(info.Hostnames), 1)

			for _, hostname := range info.Hostnames {
				if err := opnsense.ProcessIngress(info, hostname); err != nil {
					log.Printf("Failed for %s: %v", hostname, err)
				}
			}
		}
	}
}

func CreateGatewayInfo(gateway *networkingv1beta1.Gateway, clientset *kubernetes.Clientset) models.IngressInfo {
	info := models.IngressInfo{
		Name:      gateway.Name,
		Namespace: gateway.Namespace,
		Hostnames: []string{},
		LoadBalancerIP: "",
	}

	// Extract hostnames from spec.servers
	for _, server := range gateway.Spec.Servers {
		for _, host := range server.Hosts {
			if host == "*" {
				continue
			}

			// Check if already added
			found := false
			for _, existing := range info.Hostnames {
				if existing == host {
					found = true
					break
				}
			}
			if !found {
				info.Hostnames = append(info.Hostnames, host)
			}
		}
	}

	// Get IPs from the ingress gateway LoadBalancer service
	if gateway.Spec.Selector != nil {
		info.LoadBalancerIP = getLoadBalancerIPs(clientset, gateway.Spec.Selector)
	}

	return info
}

func getLoadBalancerIPs(clientset *kubernetes.Clientset, selector map[string]string) string {
	ips := []string{}

	// Convert selector map to label selector string
	labelSelector := metav1.FormatLabelSelector(&metav1.LabelSelector{
		MatchLabels: selector,
	})

	// Query services directly with label selector in istio-system
	services, err := clientset.CoreV1().Services("istio-system").List(context.TODO(), metav1.ListOptions{
		LabelSelector: labelSelector,
	})
	if err != nil {
		log.Printf("Failed to list services: %v", err)
		return ips[0]
	}

	// Extract IPs from LoadBalancer services
	for _, svc := range services.Items {
		if svc.Spec.Type != "LoadBalancer" {
			continue
		}

		for _, ingress := range svc.Status.LoadBalancer.Ingress {
			if ingress.IP != "" {
				ips = append(ips, ingress.IP)
			}
		}
	}

	return ips[0]
}
