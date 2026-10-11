# Host networking of a Proxmox node: where its management address lives.
# vmbr1 (the VLAN trunk) is left unmanaged — this module only adds an address
# on top of it.

# Installer-created WAN bridge. During setup it carries the management address;
# after lockdown it is a plain L2 wire for OPNsense's WAN NIC.
resource "proxmox_network_linux_bridge" "wan" {
  node_name = var.proxmox_node_name
  name      = "vmbr0"
  ports     = ["nic0"]
  comment   = "WAN"
  address   = var.lockdown ? null : var.wan_address
  gateway   = var.lockdown ? null : var.wan_gateway
}

import {
  to = proxmox_network_linux_bridge.wan
  id = "${var.proxmox_node_name}:vmbr0"
}

# Management on the trusted VLAN. Reachable from trusted at L2 (no router in
# the path), and from remote-access through OPNsense.
resource "proxmox_network_linux_vlan" "mgmt" {
  node_name = var.proxmox_node_name
  name      = "vmbr1.${var.mgmt_vlan}"
  comment   = "Management (trusted VLAN)"
  address   = var.mgmt_address
  gateway   = var.lockdown ? var.mgmt_gateway : null

  # Proxmox refuses a second default gateway: change vmbr0 first, never in
  # parallel with this interface.
  depends_on = [proxmox_network_linux_bridge.wan]
}

# Break-glass: cable a laptop straight into this port, set it to another
# address in the /24, open https://<breakglass_address>:8006. Works with
# OPNsense, the switch or the VLANs down. No gateway on purpose.
resource "proxmox_network_linux_bridge" "breakglass" {
  node_name = var.proxmox_node_name
  name      = "vmbr9"
  ports     = [var.breakglass_nic]
  comment   = "Break-glass (direct cable only)"
  address   = var.breakglass_address
}

resource "proxmox_virtual_environment_dns" "this" {
  node_name = var.proxmox_node_name
  domain    = "yuriy-lab.cloud"
  servers   = [var.mgmt_gateway]
}

# Proxmox services expect the node name to resolve to an address the host has,
# so it follows the management address.
resource "proxmox_virtual_environment_hosts" "this" {
  node_name = var.proxmox_node_name

  entry {
    address   = "127.0.0.1"
    hostnames = ["localhost.localdomain", "localhost"]
  }
  entry {
    address   = split("/", var.lockdown ? var.mgmt_address : var.wan_address)[0]
    hostnames = ["${var.proxmox_node_name}.yuriy-lab.cloud", var.proxmox_node_name]
  }
  entry {
    address   = "::1"
    hostnames = ["ip6-localhost", "ip6-loopback"]
  }
  entry {
    address   = "fe00::0"
    hostnames = ["ip6-localnet"]
  }
  entry {
    address   = "ff00::0"
    hostnames = ["ip6-mcastprefix"]
  }
  entry {
    address   = "ff02::1"
    hostnames = ["ip6-allnodes"]
  }
  entry {
    address   = "ff02::2"
    hostnames = ["ip6-allrouters"]
  }
  entry {
    address   = "ff02::3"
    hostnames = ["ip6-allhosts"]
  }
}
