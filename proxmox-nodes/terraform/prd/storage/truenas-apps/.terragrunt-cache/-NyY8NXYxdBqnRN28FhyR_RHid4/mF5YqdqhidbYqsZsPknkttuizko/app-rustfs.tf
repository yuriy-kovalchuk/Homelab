resource "truenas_app" "rustfs" {
  name       = "rustfs"
  custom_app = true

  compose_config = <<-EOT
    services:
      rustfs:
        image: rustfs/rustfs:latest
        restart: unless-stopped
        volumes:
          - /mnt/tank/rustfs:/data
        environment:
          RUSTFS_ACCESS_KEY: "${var.rustfs_access_key}"
          RUSTFS_SECRET_KEY: "${var.rustfs_secret_key}"
          RUSTFS_CONSOLE_ENABLE: "true"
          RUSTFS_ADDRESS: ":9000"
          RUSTFS_SERVER_DOMAINS: "rustfs.yuriykovalchuk.dev"
        command: >-
          --address :9000
          --console-enable
          --server-domains rustfs.yuriykovalchuk.dev
          /data
        labels:
          - traefik.enable=true
          - traefik.http.routers.rustfs-console.rule=Host(`rustfs.yuriykovalchuk.dev`)
          - traefik.http.routers.rustfs-console.entrypoints=websecure
          - traefik.http.routers.rustfs-console.tls.certresolver=letsencrypt
          - traefik.http.routers.rustfs-console.service=rustfs-console
          - traefik.http.services.rustfs-console.loadbalancer.server.port=9001
          - traefik.http.routers.rustfs-s3.rule=Host(`s3.yuriykovalchuk.dev`)
          - traefik.http.routers.rustfs-s3.entrypoints=websecure
          - traefik.http.routers.rustfs-s3.tls.certresolver=letsencrypt
          - traefik.http.routers.rustfs-s3.service=rustfs-s3
          - traefik.http.services.rustfs-s3.loadbalancer.server.port=9000
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
