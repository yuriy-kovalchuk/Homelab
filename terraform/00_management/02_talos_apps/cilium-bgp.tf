# Cilium BGP Peer Configuration
resource "kubectl_manifest" "cilium_bgp_peer_config" {
  depends_on = [module.cilium]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumBGPPeerConfig
    metadata:
      name: opnsense-peer
    spec:
      families:
        - afi: ipv4
          safi: unicast
          advertisements:
            matchLabels:
              advertise: bgp  # This MUST match the label on your CiliumBGPAdvertisement
      timers:
        connectRetryTimeSeconds: 120
        holdTimeSeconds: 90
        keepAliveTimeSeconds: 30
      gracefulRestart:
        enabled: true
        restartTimeSeconds: 120
      transport:
        localPort: 179
  YAML
}

# Cilium BGP Advertisement - advertise LoadBalancer service IPs
resource "kubectl_manifest" "cilium_bgp_advertisement" {
  depends_on = [module.cilium]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumBGPAdvertisement
    metadata:
      name: loadbalancer-services
      labels:
        advertise: bgp
    spec:
      advertisements:
        - advertisementType: Service
          service:
            addresses:
              - LoadBalancerIP
          selector:
            matchExpressions:
              - key: somekey
                operator: NotIn
                values:
                  - never-match-this
  YAML
}

# Cilium BGP Cluster Configuration
resource "kubectl_manifest" "cilium_bgp_cluster_config" {
  depends_on = [
    kubectl_manifest.cilium_bgp_peer_config,
    kubectl_manifest.cilium_bgp_advertisement
  ]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumBGPClusterConfig
    metadata:
      name: default
    spec:
      nodeSelector:
        matchLabels:
          kubernetes.io/os: linux
      bgpInstances:
        - name: default
          localASN: ${var.bgp_local_asn}
          peers:
            - name: opnsense
              peerASN: ${var.bgp_peer_asn}
              peerAddress: ${var.bgp_peer_address}
              peerConfigRef:
                name: opnsense-peer
              advertisements:
                matchLabels:
                  advertise: bgp
  YAML
}

# Cilium LoadBalancer IP Pool
resource "kubectl_manifest" "cilium_lb_ip_pool" {
  depends_on = [module.cilium]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2alpha1
    kind: CiliumLoadBalancerIPPool
    metadata:
      name: default-pool
    spec:
      blocks:
        - start: ${var.cilium_lb_ip_range_start}
          stop: ${var.cilium_lb_ip_range_end}
  YAML
}
