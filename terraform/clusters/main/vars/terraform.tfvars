cluster_name   = "talos-prd-cluster"
gateway        = "10.0.8.254"
talos_version  = "v1.12.2"
cni_name       = "none"
image_registry = "factory.talos.dev/metal-installer"
extensions = [
  "siderolabs/iscsi-tools",
  "siderolabs/util-linux-tools",
]

extra_kernel_args = []

control_plane_nodes = [
  {
    ip        = "10.0.8.2"
    hostname  = "yulia"
    interface = "enp2s0"
    disk      = "/dev/nvme0n1"
    wipe      = true
    extensions = [
      "siderolabs/iscsi-tools",
      "siderolabs/util-linux-tools",
      "siderolabs/amd-ucode",
      "siderolabs/amdgpu",
    ]
    extra_kernel_args = [
      #      "amd_iommu=on",
      #"iommu=pt",
    ]
    gpu_passthrough = {
      enabled = false
      pci_devices = [
        {
          pci_address   = "0000:c4:00.0"
          vendor_device = "1002:1900"
          resource_name = "amd.com/780m"
        },
        {
          pci_address   = "0000:c4:00.1"
          vendor_device = "1002:1640"
          resource_name = "amd.com/780m-audio"
        }
      ]
      node_labels = {
        "gpu.amd.com/780m" = "true"
      }
    }
  },
  { ip = "10.0.8.3", hostname = "lisa", interface = "eno1", disk = "/dev/sda", wipe = true },
  { ip = "10.0.8.4", hostname = "thea", interface = "eno1", disk = "/dev/nvme0n1", wipe = true },
]

