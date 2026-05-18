resource "truenas_pool" "main" {
  name = var.truenas_pool_name

  topology = jsonencode({
    data = [
      {
        type  = "STRIPE"
        disks = var.truenas_pool_disks
      }
    ]
  })
}
