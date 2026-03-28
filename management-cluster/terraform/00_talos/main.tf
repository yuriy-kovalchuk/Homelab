module "talos_cluster" {
  source = "../../../terraform/modules/talos-cluster"

  cluster_name   = "talos-management"
  talos_version  = "v1.12.6"
  cni_name       = "none"
  image_registry = "factory.talos.dev/metal-installer"
  extensions     = ["siderolabs/iscsi-tools", "siderolabs/util-linux-tools"]


  control_plane_nodes = [
    {
      ip          = "10.0.2.2"
      hostname    = "jade"
      interface   = "eno1"
      gateway     = "10.0.2.254"
      disk        = "/dev/sda"
      wipe        = true
      node_labels = { "management-node" = "true" }
      extensions = [
        "siderolabs/iscsi-tools",
        "siderolabs/util-linux-tools",
      ]
    },
  ]
}
