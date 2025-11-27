package opnsense

import (
	"bytes"
	"crypto/tls"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"dns-sync/internal/models"
)

// Globals
var (
	URI       string
	BasicAuth string
	HTTPClient  *http.Client

	lastPostTime time.Time
	applyMu      sync.Mutex
)

// InitEnv reads environment variables for OPNsense
func InitEnv() {
	uri := mustGetEnv("OPNSENSE_URI")
	key := mustGetEnv("OPNSENSE_KEY")
	secret := mustGetEnv("OPNSENSE_SECRET")

	URI = uri
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

func SendIngressInfo(info models.HttRouteInfo) error {
	if len(info.Hostnames) == 0 {
		return fmt.Errorf("no hostnames in %+v", info)
	}
	if len(info.Ip) == 0 {
		return fmt.Errorf("no IPs found in %+v", info)
	}

	ip := info.Ip[0]

	for _, fullHost := range info.Hostnames {
		h, d, err := splitHost(fullHost)
		if err != nil {
			return err
		}

        // Lookup
		exists, uuid, currentIP, err := findHostOverride(h, d)
		if err != nil {
			return err
		}

		// No change needed
		if exists && currentIP == ip {
			log.Printf("[SKIP] %s.%s already = %s", h, d, ip)
			continue
		}

		// Build JSON
		payload, _ := json.Marshal(models.HostOverride{
			Host: models.HostEntry{
				Enabled:     "1",
				Hostname:    h,
				Domain:      d,
				RR:          "A",
				Server:      ip,
				Description: fmt.Sprintf("%s/%s", info.Namespace, info.Name),
			},
		})

		// POST to add or update
		endpoint := "addHostOverride"
		if exists {
			endpoint = "setHostOverride/" + uuid
		}

		if err := postUnbound(endpoint, payload); err != nil {
			return err
		}

		action := "added"
		if exists {
			action = "updated"
		}
		log.Printf("[%s] %s.%s → %s", strings.ToUpper(action), h, d, ip)
	}

	scheduleApply()
	return nil
}

func splitHost(fqdn string) (string, string, error) {
	parts := strings.SplitN(fqdn, ".", 2)
	if len(parts) != 2 {
		return "", "", fmt.Errorf("invalid hostname: %s", fqdn)
	}
	return parts[0], parts[1], nil
}

func findHostOverride(host, domain string) (bool, string, string, error) {
	url := fmt.Sprintf("%s/api/unbound/settings/searchHostOverride", URI)

	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("Authorization", "Basic "+BasicAuth)

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return false, "", "", err
	}
	defer resp.Body.Close()

	var out struct {
		Rows []struct {
			UUID     string `json:"uuid"`
			Hostname string `json:"hostname"`
			Domain   string `json:"domain"`
			Server   string `json:"server"`
		} `json:"rows"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return false, "", "", err
	}

	for _, r := range out.Rows {
		if r.Hostname == host && r.Domain == domain {
			return true, r.UUID, r.Server, nil
		}
	}
	return false, "", "", nil
}
func postUnbound(path string, payload []byte) error {
	url := fmt.Sprintf("%s/api/unbound/settings/%s", URI, path)

	req, _ := http.NewRequest("POST", url, bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Basic "+BasicAuth)

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("unbound API %s → HTTP %d", path, resp.StatusCode)
	}
	return nil
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
	urlStr := fmt.Sprintf("%s/api/unbound/service/reconfigure", URI)
	req, _ := http.NewRequest("POST", urlStr, nil)
	req.Header.Set("Authorization", "Basic "+BasicAuth)

	resp, err := HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer func(Body io.ReadCloser) {
		err := Body.Close()
		if err != nil {

		}
	}(resp.Body)

	if resp.StatusCode >= 200 && resp.StatusCode < 300 {
		log.Println("Applied OPNsense changes")
		return nil
	}
	return fmt.Errorf("HTTP %d applying changes", resp.StatusCode)
}
