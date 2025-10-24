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
