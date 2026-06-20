resource "truenas_app" "opencloud" {
  name       = "opencloud"
  custom_app = true

  compose_config = <<-EOT
    services:
      opencloud:
        image: opencloudeu/opencloud-rolling:latest
        restart: unless-stopped
        entrypoint:
          - /bin/sh
          - -c
          - |
            opencloud init || true
            opencloud server
        volumes:
          - /mnt/tank/opencloud:/var/lib/opencloud
        environment:
          OC_URL: https://opencloud.yuriykovalchuk.dev
          OC_DOMAIN: opencloud.yuriykovalchuk.dev
          OC_LOG_LEVEL: warn
          PROXY_TLS: "false"
          IDM_CREATE_DEMO_USERS: "false"
          INITIAL_ADMIN_PASSWORD: "${var.opencloud_admin_password}"
        labels:
          - traefik.enable=true
          - traefik.http.routers.opencloud.rule=Host(`opencloud.yuriykovalchuk.dev`)
          - traefik.http.routers.opencloud.entrypoints=websecure
          - traefik.http.routers.opencloud.tls.certresolver=letsencrypt
          - traefik.http.services.opencloud.loadbalancer.server.port=9200
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
