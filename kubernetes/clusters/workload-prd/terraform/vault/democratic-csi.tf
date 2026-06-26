resource "vault_kv_secret_v2" "democratic_csi_nfs" {
  mount               = "kubernetes"
  name                = "democratic-csi-nfs/config"
  delete_all_versions = true

  data_json = jsonencode({
    "driver-config-file.yaml" = yamlencode({
      httpConnection = {
        host          = "10.0.3.3"
        port          = 8443
        username      = "truenas_admin"
        password      = var.truenas_token
        allowInsecure = false
      }
      zfs = {
        datasetParentName                  = "tank/kubernetes/nfs"
        detachedSnapshotsDatasetParentName = "tank/kubernetes/nfs-snapshots"
        datasetEnableQuotas                = true
        datasetEnableReservation           = false
        datasetPermissionsMode             = "0777"
        datasetPermissionsUser             = 0
        datasetPermissionsGroup            = 0
      }
      nfs = {
        shareAlldirs        = false
        shareAllowedHosts   = []
        shareAllowedNetworks = []
        shareMaprootUser    = "root"
        shareMaprootGroup   = "wheel"
        shareMapallUser     = ""
        shareMapallGroup    = ""
      }
    })
  })
}

resource "vault_kv_secret_v2" "democratic_csi_iscsi" {
  mount               = "kubernetes"
  name                = "democratic-csi-iscsi/config"
  delete_all_versions = true

  data_json = jsonencode({
    "driver-config-file.yaml" = yamlencode({
      httpConnection = {
        host          = "10.0.3.3"
        port          = 8443
        username      = "truenas_admin"
        password      = var.truenas_token
        allowInsecure = false
      }
      zfs = {
        datasetParentName      = "tank/kubernetes/iscsi"
        zvolEnableReservation  = false
      }
      iscsi = {
        targetPortal = "10.0.3.3:3260"
        namePrefix   = "iqn.2005-10.org.freenas.ctl:"
        nameSuffix   = ""
        targetGroups = [
          {
            targetGroupPortalGroup    = 1
            targetGroupInitiatorGroup = 1
            targetGroupAuthType       = "None"
            targetGroupAuthGroup      = null
          }
        ]
        extentInsecureTpc            = true
        extentXenCompat              = false
        extentDisablePhysicalBlocksize = true
        extentBlocksize              = 512
        extentRpm                    = "SSD"
        extentAvailThreshold         = 0
      }
    })
  })
}
