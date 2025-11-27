package models


type HostOverride struct {
	Host HostEntry `json:"host"`
}

type HostEntry struct {
	Enabled     string `json:"enabled"`     // "1" or "0"
	Hostname    string `json:"hostname"`    // e.g. "api"
	Domain      string `json:"domain"`      // e.g. "example.com"
	RR          string `json:"rr"`          // "A" or "AAAA"
	Server      string `json:"server"`      // IP address
	Description string `json:"description"` // optional
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
