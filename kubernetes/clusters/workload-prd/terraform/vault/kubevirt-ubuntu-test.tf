locals {
  kubevirt_ubuntu_test_userdata = <<-EOT
    #cloud-config
    hostname: ubuntu-test
    users:
      - name: ${var.kubevirt_ubuntu_test_username}
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        groups: sudo
        lock_passwd: false
        passwd: "${var.kubevirt_ubuntu_test_passwd}"
    chpasswd:
      expire: false
    ssh_pwauth: true
    EOT
}

resource "vault_kv_secret_v2" "kubevirt_ubuntu_test" {
  mount               = "kubernetes"
  name                = "kubevirt-ubuntu-test/cloudinit"
  delete_all_versions = true

  data_json = jsonencode({
    userdata = local.kubevirt_ubuntu_test_userdata
  })
}
