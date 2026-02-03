# Vault Secrets for Kubernetes ExternalSecrets
# Only includes secrets actually used by the main cluster

resource "vault_kv_secret_v2" "prd" {
  mount = vault_mount.kubernetes.path
  name  = "prd"
  data_json = jsonencode({
    "cloudflare-token" = var.cloudflare_token
  })
}

resource "vault_kv_secret_v2" "prd_authentik" {
  mount = vault_mount.kubernetes.path
  name  = "prd/authentik"
  data_json = jsonencode({
    pg_user             = var.authentik_pg_user
    pg_password         = var.authentik_pg_password
    auth_admin_password = var.authentik_admin_password
  })
}

resource "vault_kv_secret_v2" "prd_democratic_csi" {
  mount = vault_mount.kubernetes.path
  name  = "prd/democratic-csi"
  data_json = jsonencode({
    iscsi_config = yamlencode({
      driver = "freenas-api-iscsi"
      httpConnection = {
        allowInsecure = true
        apiKey        = var.truenas_api_key
        host          = "10.0.2.3"
        port          = 80
        protocol      = "http"
      }
      instance_id = null
      iscsi = {
        targetPortal   = "10.0.2.3:3260"
        targetPortals  = []
        interface      = null
        namePrefix     = "csi-"
        nameSuffix     = "-cluster"
        targetGroups = [{
          targetGroupPortalGroup    = 1
          targetGroupInitiatorGroup = 1
          targetGroupAuthType       = "None"
          targetGroupAuthGroup      = null
        }]
        extentCommentTemplate  = "{{ parameters.[csi.storage.k8s.io/pvc/namespace] }}/{{ parameters.[csi.storage.k8s.io/pvc/name] }}"
        extentInsecureTpc      = true
        extentXenCompat        = false
        extentRpm              = "SSD"
        extentBlocksize        = 512
        extentAvailThreshold   = 0
      }
      zfs = {
        datasetParentName                  = "tank-1/k8s/talos/iscsi/volumes"
        detachedSnapshotsDatasetParentName = "tank-1/k8s/talos/iscsi/snapshots"
        zvolCompression                    = null
        zvolDedup                          = null
        zvolEnableReservation              = false
        zvolBlocksize                      = null
        datasetProperties = {
          "org.freenas:description" = "{{ parameters.[csi.storage.k8s.io/pvc/namespace] }}/{{ parameters.[csi.storage.k8s.io/pvc/name] }}"
        }
      }
    })
    nfs_config = jsonencode({
      driver = "freenas-api-nfs"
      httpConnection = {
        protocol      = "http"
        host          = "10.0.2.3"
        port          = 80
        apiKey        = var.truenas_api_key
        allowInsecure = true
      }
      zfs = {
        datasetParentName                  = "tank-1/k8s/talos/nfs/volumes"
        detachedSnapshotsDatasetParentName = "tank-1/k8s/talos/nfs/snapshots"
        datasetPermissionsMode             = "0777"
        datasetPermissionsUser             = 0
        datasetPermissionsGroup            = 0
      }
      nfs = {
        shareHost           = "10.0.2.3"
        shareAlloedNetworks = ["0.0.0.0/0"]
        shareMaprootUser    = "root"
        shareMaprootGroup   = "wheel"
      }
    })
  })
}

resource "vault_kv_secret_v2" "prd_grafana" {
  mount = vault_mount.kubernetes.path
  name  = "prd/grafana"
  data_json = jsonencode({
    "admin-user"     = var.grafana_admin_user
    "admin-password" = var.grafana_admin_password
    client_id        = var.grafana_client_id
    client_secret    = var.grafana_client_secret
  })
}

resource "vault_kv_secret_v2" "prd_minio" {
  mount = vault_mount.kubernetes.path
  name  = "prd/minio"
  data_json = jsonencode({
    S3_ACCESS_KEY = var.minio_s3_access_key
    S3_SECRET_KEY = var.minio_s3_secret_key
    rootUser      = var.minio_root_user
    rootPassword  = var.minio_root_password
  })
}

resource "vault_kv_secret_v2" "prd_mimir" {
  mount = vault_mount.kubernetes.path
  name  = "prd/mimir"
  data_json = jsonencode({
    access_key_id     = var.mimir_access_key
    secret_access_key = var.mimir_secret_key
  })
}

resource "vault_kv_secret_v2" "prd_opnsense" {
  mount = vault_mount.kubernetes.path
  name  = "prd/opnsense"
  data_json = jsonencode({
    secret = var.opnsense_secret
  })
}
