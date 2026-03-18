# Harbor Projects Configuration

# Project to store custom and umbrella Helm charts as OCI artifacts
resource "harbor_project" "charts" {
  name        = "charts"
  public      = true

  depends_on = [helm_release.harbor]
}
