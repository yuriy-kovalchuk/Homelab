output "talos_registry_mirrors" {
  description = <<-EOT
    Ready-made machine.registries.mirrors content for phase 2. Each upstream host
    maps to its proxy-cache project; overridePath stops containerd appending
    another /v2 to a path that already contains one.

    skipFallback is deliberately absent, so it keeps its default of false: if
    Harbor is down or denies a pull, containerd falls back to the upstream
    registry. Setting it to true is what turns Harbor into an enforcing gate —
    and simultaneously makes it a hard dependency for every image pull in the
    cluster. That is a phase 4 decision, not a phase 1 one.
  EOT

  value = {
    for key, cache in local.proxy_caches :
    cache.mirror_host => {
      endpoints    = ["${var.harbor_url}/v2/${key}"]
      overridePath = true
    }
  }
}

output "proxy_cache_projects" {
  description = "Proxy cache project name -> upstream endpoint"
  value       = { for k, v in local.proxy_caches : k => v.endpoint_url }
}

output "forgejo_runner_username" {
  description = "Full robot account name (Harbor prefixes it with robot$ and the project name)"
  value       = harbor_robot_account.forgejo_runner.full_name
}

output "forgejo_runner_secret" {
  description = "Robot account secret — feed this to the Forgejo runners, ideally via Vault"
  value       = harbor_robot_account.forgejo_runner.secret
  sensitive   = true
}
