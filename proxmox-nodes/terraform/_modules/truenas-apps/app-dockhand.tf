resource "truenas_app" "dockhand" {
  name       = "dockhand"
  custom_app = true

  compose_config = <<-EOT
    services:
      dockhand:
        image: fnsys/dockhand:latest
        restart: unless-stopped
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
          - dockhand_data:/app/data
        labels:
          - traefik.enable=true
          - traefik.http.routers.dockhand.rule=Host(`dockhand.yuriykovalchuk.dev`)
          - traefik.http.routers.dockhand.entrypoints=websecure
          - traefik.http.routers.dockhand.tls.certresolver=letsencrypt
          - traefik.http.services.dockhand.loadbalancer.server.port=3000
        deploy:
          resources:
            limits:
              cpus: '0.5'
              memory: 1024M
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy
        external: true

    volumes:
      dockhand_data:
  EOT
}
