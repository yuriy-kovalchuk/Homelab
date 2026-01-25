# Gateway API CRDs
# Using kubectl provider to apply the CRDs from the official release
# Fetch the manifest from GitHub
data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_version}/${var.gateway_api_channel}-install.yaml"
}

# Split the YAML into individual documents
resource "kubectl_manifest" "gateway_api_crds" {
  for_each = {
    for idx, doc in split("---", data.http.gateway_api_crds.response_body) :
    idx => doc 
    if trimspace(doc) != "" && length(regexall("kind: ", doc)) > 0
  }

  yaml_body = each.value

  lifecycle {
    ignore_changes = [yaml_body]
  }
}
