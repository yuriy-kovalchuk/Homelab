resource "truenas_app" "rustfs" {
  name       = "rustfs"
  custom_app = true

  compose_config = <<-EOT
    services:
      rustfs:
        # Pinned to the digest of the image validated on 2026-07-12 — console
        # and S3 host-parsing behavior change between releases, do not float
        image: rustfs/rustfs@sha256:fa19210ac4697c79d7ccca1ec9b0eb91aebacc6691991ffb14014bb3c67e6cc3
        restart: unless-stopped
        # Direct host ports for the console — the embedded console cannot
        # authenticate behind a split-domain reverse proxy (rustfs/rustfs#3062)
        ports:
          - "9000:9000"
          - "9001:9001"
        volumes:
          - /mnt/tank/rustfs:/data
        environment:
          RUSTFS_ACCESS_KEY: "${var.rustfs_access_key}"
          RUSTFS_SECRET_KEY: "${var.rustfs_secret_key}"
          RUSTFS_CONSOLE_ENABLE: "true"
          RUSTFS_ADDRESS: ":9000"
        command: >-
          --address :9000
          --console-enable
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
        deploy:
          resources:
            limits:
              cpus: '1.0'
              memory: 1G
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
