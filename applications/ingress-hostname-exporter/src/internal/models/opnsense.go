package models

// HostOverride represents a host override in OPNsense Unbound
type HostOverride struct {
	Host struct {
		Enabled     string `json:"enabled"`     // "1" for enabled, "0" for disabled
		Hostname    string `json:"hostname"`    // Hostname portion of the FQDN
		Domain      string `json:"domain"`      // Domain portion of the FQDN
		RR          string `json:"rr"`          // Record type, e.g., "A"
		MxPrio      string `json:"mxprio"`      // Optional MX priority
		Mx          string `json:"mx"`          // Optional MX server
		Server      string `json:"server"`      // IP address of the host override
		Description string `json:"description"` // Optional description
	} `json:"host"`
}

// SearchResponse represents the response from OPNsense searchHostOverride API
type SearchResponse struct {
	Rows []struct {
		UUID     string `json:"uuid"`
		Hostname string `json:"hostname"`
		Domain   string `json:"domain"`
		Server   string `json:"server"`
	} `json:"rows"`
	RowCount int `json:"rowCount"`
}
