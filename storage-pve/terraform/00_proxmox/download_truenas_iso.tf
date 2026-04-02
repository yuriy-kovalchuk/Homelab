resource "proxmox_download_file" "download_truenas_iso" {
  content_type = "iso"
  node_name    = "gaia"
  datastore_id = "local"
  file_name    = "true_nas_25_10_1.iso"
  url          = "https://download.truenas.com/TrueNAS-SCALE-Goldeye/25.10.2.1/TrueNAS-SCALE-25.10.2.1.iso?download=1"
}


