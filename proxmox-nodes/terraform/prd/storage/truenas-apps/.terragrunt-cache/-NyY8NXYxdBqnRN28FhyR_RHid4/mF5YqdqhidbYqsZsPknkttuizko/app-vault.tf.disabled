resource "truenas_app" "vault" {
  name       = "vault"
  custom_app = true

  # After first apply, initialize Vault manually:
  #   docker exec -it vault_vault_1 vault operator init
  # Save the unseal keys and root token securely.
  # Then unseal:
  #   docker exec -it vault_vault_1 vault operator unseal <key>  (repeat 3x)
  # Migrate secrets from the Kubernetes Vault before decommissioning it.

  compose_config = <<-EOT
    services:
      vault:
        image: hashicorp/vault:1.21.1
        restart: unless-stopped
        cap_add:
          - IPC_LOCK
        command: server
        volumes:
          - /mnt/tank/vault:/vault/data
        environment:
          VAULT_LOCAL_CONFIG: '{"ui":true,"storage":{"raft":{"path":"/vault/data","node_id":"node1"}},"listener":[{"tcp":{"address":"0.0.0.0:8200","tls_disable":true}}],"cluster_addr":"http://vault:8201","api_addr":"https://vault.yuriykovalchuk.dev"}'
        labels:
          - traefik.enable=true
          - traefik.http.routers.vault.rule=Host(`vault.yuriykovalchuk.dev`)
          - traefik.http.routers.vault.entrypoints=websecure
          - traefik.http.routers.vault.tls.certresolver=letsencrypt
          - traefik.http.services.vault.loadbalancer.server.port=8200
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
