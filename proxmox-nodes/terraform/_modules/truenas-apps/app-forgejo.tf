resource "truenas_app" "forgejo" {
  name       = "forgejo"
  custom_app = true

  # Migrating from Kubernetes: copy existing Forgejo data to /mnt/tank/forgejo
  # before applying. The directory structure Forgejo expects:
  #   /mnt/tank/forgejo/gitea/       — app config and DB
  #   /mnt/tank/forgejo/repositories/ — git repos

  compose_config = <<-EOT
    services:
      forgejo:
        image: codeberg.org/forgejo/forgejo:15
        restart: unless-stopped
        ports:
          - "2222:22"
        volumes:
          - /mnt/tank/forgejo:/data
        environment:
          USER_UID: "1000"
          USER_GID: "1000"
          FORGEJO__database__DB_TYPE: sqlite3
          FORGEJO__server__ROOT_URL: https://forgejo.yuriykovalchuk.dev
          FORGEJO__server__SSH_DOMAIN: forgejo.yuriykovalchuk.dev
          FORGEJO__server__SSH_PORT: "2222"
          FORGEJO__server__DOMAIN: forgejo.yuriykovalchuk.dev
        labels:
          - traefik.enable=true
          - traefik.http.routers.forgejo.rule=Host(`forgejo.yuriykovalchuk.dev`)
          - traefik.http.routers.forgejo.entrypoints=websecure
          - traefik.http.routers.forgejo.tls.certresolver=letsencrypt
          - traefik.http.services.forgejo.loadbalancer.server.port=3000
        deploy:
          resources:
            limits:
              cpus: '1.0'
              memory: 512M
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
