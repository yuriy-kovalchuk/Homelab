cluster_name     = "talos-prd-cluster"
gateway          = "10.0.8.254"
talos_version    = "v1.11.0"
cni_name         = "none"
image_registry   = "factory.talos.dev/nocloud-installer"

control_plane_nodes = [
  { ip = "10.0.8.2", hostname = "yulia", interface = "eno1", disk = "/dev/sda", wipe = true},
  { ip = "10.0.8.3", hostname = "lisa", interface = "eno1", disk = "/dev/sda", wipe = true },
  { ip = "10.0.8.4", hostname = "thea", interface = "eno1", disk = "/dev/sdb", wipe = true },
]

