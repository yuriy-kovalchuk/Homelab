package main

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "log"
    "net/http"
    "net/url"
    "os"
    "path/filepath"
    "sync"
    "time"

    networkingv1 "k8s.io/api/networking/v1"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/client-go/kubernetes"
    "k8s.io/client-go/rest"
    "k8s.io/client-go/tools/clientcmd"
)

type IngressInfo struct {
    Name           string
    Namespace      string
    LoadBalancerIP string
    Hostnames      []string
}

type AuthRequest struct {
    Password string `json:"password"`
}

type AuthResponse struct {
    Session struct {
        SID      string `json:"sid"`
        Validity int    `json:"validity"` // in seconds
    } `json:"session"`
}

type AuthCache struct {
    sync.Mutex
    sid       string
    expiresAt time.Time
}

var (
    authCache       = make(map[string]*AuthCache) // key: endpoint
    piholePassword  string
    piholeEndpoints []string
)

func initEnv() {
    piholePassword = os.Getenv("PIHOLE_PASSWORD")
    if piholePassword == "" {
        log.Fatal("PIHOLE_PASSWORD is not set")
    }

    endpointsEnv := os.Getenv("PIHOLE_ENDPOINTS")
    if endpointsEnv == "" {
        log.Fatal("PIHOLE_ENDPOINTS is not set")
    }

    for _, ep := range bytes.Split([]byte(endpointsEnv), []byte(",")) {
        trimmed := string(bytes.TrimSpace(ep))
        if trimmed != "" {
            piholeEndpoints = append(piholeEndpoints, trimmed)
        }
    }

    log.Printf("Loaded %d Pi-hole endpoints from environment", len(piholeEndpoints))
    log.Printf("endpoints: %s", piholeEndpoints)
}

func main() {

    initEnv()

    clientset, err := getClientset()
    if err != nil {
        log.Fatalf("Kubernetes client error: %v", err)
    }
    watchIngresses(clientset)
}

func getClientset() (*kubernetes.Clientset, error) {
    if config, err := rest.InClusterConfig(); err == nil {
        log.Println("Using in-cluster config.")
        return kubernetes.NewForConfig(config)
    }

    kubeconfig := os.Getenv("KUBECONFIG")
    if kubeconfig == "" {
        kubeconfig = filepath.Join(os.Getenv("HOME"), ".kube", "config")
    }
    config, err := clientcmd.BuildConfigFromFlags("", kubeconfig)
    if err != nil {
        return nil, fmt.Errorf("cannot load kubeconfig: %w", err)
    }
    log.Println("Using local kubeconfig.")
    return kubernetes.NewForConfig(config)
}

func watchIngresses(clientset *kubernetes.Clientset) {
    for {
        watcher, err := clientset.NetworkingV1().Ingresses("").Watch(context.TODO(), metav1.ListOptions{})
        if err != nil {
            log.Printf("Watch error: %v", err)
            time.Sleep(30 * time.Second)
            continue
        }

        log.Println("Watching ingress resources...")
        for event := range watcher.ResultChan() {
            ingress, ok := event.Object.(*networkingv1.Ingress)
            if !ok {
                log.Println("Unexpected object type")
                continue
            }
            info := createIngressInfo(ingress)
            for _, endpoint := range piholeEndpoints {
                fmt.Printf("Sending Ingress Info: %+v to %s\n", info, endpoint)
                sendIngressInfo(info, endpoint)
            }
        }
        log.Println("Watcher closed. Reconnecting...")
    }
}

func createIngressInfo(ingress *networkingv1.Ingress) IngressInfo {

    info := IngressInfo{
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
    } else {
        info.LoadBalancerIP = "No LoadBalancer IP assigned"
    }
    for _, rule := range ingress.Spec.Rules {
        info.Hostnames = append(info.Hostnames, rule.Host)
    }
    return info
}

func sendIngressInfo(info IngressInfo, endpoint string) {

    sid, err := getAuth(endpoint)

    if err != nil {
        log.Printf("Skipping update due to auth failure: %v", err)
        return
    }

    client := &http.Client{}
    for _, hostname := range info.Hostnames {
        payload := url.QueryEscape(fmt.Sprintf("%s %s", info.LoadBalancerIP, hostname))
        urlStr := fmt.Sprintf("%s/api/config/dns/hosts/%s?sid=%s", endpoint, payload, sid)

        req, err := http.NewRequest("PUT", urlStr, nil)
        if err != nil {
            log.Printf("Request creation failed: %v", err)
            continue
        }

        resp, err := client.Do(req)
        if err != nil {
            log.Printf("PUT request failed: %v", err)
            continue
        }
        body, _ := io.ReadAll(resp.Body)

        err = resp.Body.Close()
        if err != nil {
            log.Printf("Closing body stream failed: %v", err)
            return
        }

        log.Printf("PUT to %s returned [%d]: %s", urlStr, resp.StatusCode, string(body))
    }
}

func getAuth(endpoint string) (string, error) {

    cache, ok := authCache[endpoint]
    if !ok {
        cache = &AuthCache{}
        authCache[endpoint] = cache
    }

    cache.Lock()
    defer cache.Unlock()

    if time.Now().Before(cache.expiresAt) {
        return cache.sid, nil // return cached SID
    }

    bodyJSON, _ := json.Marshal(AuthRequest{Password: piholePassword})
    resp, err := http.Post(fmt.Sprintf("%s/api/auth", endpoint), "application/json", bytes.NewBuffer(bodyJSON))
    if err != nil {
        return "", fmt.Errorf("auth request failed: %w", err)
    }

    defer func(Body io.ReadCloser) {
        err := Body.Close()
        if err != nil {
            log.Printf("Closing body stream failed: %v", err)
            return
        }
    }(resp.Body)


    body, _ := io.ReadAll(resp.Body)
    if resp.StatusCode != http.StatusOK {
        return "", fmt.Errorf("auth failed (%d): %s", resp.StatusCode, string(body))
    }

    // Instead of unmarshaling into a structure, store the body as a RawMessage
    var rawResponse json.RawMessage
    if err := json.Unmarshal(body, &rawResponse); err != nil {
        return "", fmt.Errorf("failed to parse raw response: %v", err)
    }

    // Now you have the raw JSON response in rawResponse
    fmt.Printf("Raw Response Body: %s\n", string(rawResponse))

    var authResp AuthResponse
    if err := json.Unmarshal(body, &authResp); err != nil {
        return "", fmt.Errorf("response parse failed: %w", err)
    }

    // Cache SID with expiration time
    cache.sid = authResp.Session.SID
    cache.expiresAt = time.Now().Add(time.Duration(authResp.Session.Validity) * time.Second)

    return cache.sid, nil
}
