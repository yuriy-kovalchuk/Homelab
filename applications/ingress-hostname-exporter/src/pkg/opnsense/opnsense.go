package opnsense

import (
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"ingress-hostname-exporter/internal/models"
)

// Globals
var (
	OpnsenseURI string
	BasicAuth   string
	HTTPClient  *http.Client

	lastPostTime time.Time
	applyMu      sync.Mutex
)

// InitEnv reads environment variables for OPNsense
func InitEnv() {
	uri := mustGetEnv("OPNSENSE_URI")
	key := mustGetEnv("OPNSENSE_KEY")
	secret := mustGetEnv("OPNSENSE_SECRET")

	OpnsenseURI = uri
	BasicAuth = base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%s:%s", key, secret)))
}

func mustGetEnv(name string) string {
	if v := strings.TrimSpace(os.Getenv(name)); v != "" {
		return v
	}
	log.Fatalf("Missing env: %s", name)
	return ""
}

// InitHTTPClient initializes the HTTP client, optionally skipping TLS verification
func InitHTTPClient() {
	skip := strings.ToLower(os.Getenv("OPNSENSE_SKIP_TLS_VERIFY"))
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: skip == "true" || skip == "1"},
		DialContext: (&net.Dialer{
			Timeout:   30 * time.Second,
			KeepAlive: 30 * time.Second,
		}).DialContext,
		IdleConnTimeout:       90 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}
	HTTPClient = &http.Client{Transport: tr, Timeout: 30 * time.Second}
	if tr.TLSClientConfig.InsecureSkipVerify {
		log.Println("TLS verification DISABLED")
	}
}

// ProcessIngress adds or updates an ingress hostname in OPNsense
func ProcessIngress(info models.IngressInfo, fqdn string) error {
	if info.LoadBalancerIP == "" {
		return nil
	}

	existingIP, err := CheckExistingRecord(fqdn)
	if err != nil {
		return err
	}

	if existingIP == info.LoadBalancerIP {
		log.Printf("Skip %s (same IP)", fqdn)
		return nil
	}

	return SendIngressInfo(info, fqdn)
}

// CheckExistingRecord queries OPNsense to see if the host override already exists
func CheckExistingRecord(fqdn string) (string, error) {
	urlStr := fmt.Sprintf("%s/api/unbound/settings/searchHostOverride", OpnsenseURI)
	req, _ := http.NewRequest("GET", urlStr, nil)
	req.Header.Set("Authorization", "Basic "+BasicAuth)

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var sr models.SearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&sr); err != nil {
		return "", err
	}

	for _, row := range sr.Rows {
		if fmt.Sprintf("%s.%s", row.Hostname, row.Domain) == fqdn {
			return row.Server, nil
		}
	}
	return "", nil
}

// SendIngressInfo creates a host override in OPNsense
func SendIngressInfo(info models.IngressInfo, fqdn string) error {
	parts := strings.SplitN(fqdn, ".", 2)
	if len(parts) < 2 {
		return fmt.Errorf("invalid FQDN: %s", fqdn)
	}
	hostname, domain := parts[0], parts[1]

	var payload models.HostOverride
	payload.Host.Enabled = "1"
	payload.Host.Hostname = hostname
	payload.Host.Domain = domain
	payload.Host.RR = "A"
	payload.Host.Server = info.LoadBalancerIP
	payload.Host.Description = fmt.Sprintf("Ingress %s/%s", info.Namespace, info.Name)
	log.Printf("Sending %s", payload)

	jsonPayload, _ := json.Marshal(payload)
	urlStr := fmt.Sprintf("%s/api/unbound/settings/AddHostOverride", OpnsenseURI)
	req, _ := http.NewRequest("POST", urlStr, strings.NewReader(string(jsonPayload)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Basic "+BasicAuth)

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		log.Printf("Added %s (%s)", fqdn, info.LoadBalancerIP)
		scheduleApply()
		return nil
	}
	return fmt.Errorf("HTTP %d adding %s", resp.StatusCode, fqdn)
}

// scheduleApply debounces OPNsense reconfigure calls (5 seconds)
func scheduleApply() {
	applyMu.Lock()
	defer applyMu.Unlock()

	lastPostTime = time.Now()

	go func(scheduled time.Time) {
		time.Sleep(5 * time.Second)
		applyMu.Lock()
		defer applyMu.Unlock()
		if scheduled == lastPostTime {
			if err := ApplyChanges(); err != nil {
				log.Printf("Apply failed: %v", err)
			}
		}
	}(lastPostTime)
}

// ApplyChanges triggers OPNsense to apply host overrides
func ApplyChanges() error {
	urlStr := fmt.Sprintf("%s/api/unbound/service/reconfigure", OpnsenseURI)
	req, _ := http.NewRequest("POST", urlStr, nil)
	req.Header.Set("Authorization", "Basic "+BasicAuth)

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		log.Println("Applied OPNsense changes")
		return nil
	}
	return fmt.Errorf("HTTP %d applying changes", resp.StatusCode)
}
