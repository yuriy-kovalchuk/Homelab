resource "kubernetes_manifest" "cilium_l2_policy" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumL2AnnouncementPolicy"
    metadata = {
      name      = "default-l2-announcement-policy"
    }
    spec = {
      externalIPs     = true
      loadBalancerIPs = true
    }
  }
}

resource "kubernetes_manifest" "cilium_lb_pool" {
  depends_on = [helm_release.cilium]
  manifest = {
    apiVersion = "cilium.io/v2alpha1"
    kind       = "CiliumLoadBalancerIPPool"
    metadata = {
      name = "services-ip-pool"
    }
    spec = {
      blocks = [
        {
          start = "10.0.8.50"
          stop  = "10.0.8.200"
        }
      ]
    }
  }
}