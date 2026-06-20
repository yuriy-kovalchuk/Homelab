resource "truenas_app" "immich" {
  name       = "immich"
  custom_app = true

  compose_config = <<-EOT
    services:
      server:
        image: ghcr.io/immich-app/immich-server:release
        restart: unless-stopped
        volumes:
          - /mnt/tank/immich/uploads:/usr/src/app/upload
          - /etc/localtime:/etc/localtime:ro
        environment:
          DB_HOSTNAME: db
          DB_USERNAME: immich
          DB_PASSWORD: "${var.immich_db_password}"
          DB_DATABASE_NAME: immich
          REDIS_HOSTNAME: redis
        depends_on:
          db:
            condition: service_healthy
          redis:
            condition: service_healthy
        labels:
          - traefik.enable=true
          - traefik.http.routers.immich.rule=Host(`immich.yuriykovalchuk.dev`)
          - traefik.http.routers.immich.entrypoints=websecure
          - traefik.http.routers.immich.tls.certresolver=letsencrypt
          - traefik.http.services.immich.loadbalancer.server.port=2283
        networks:
          - proxy
          - internal

      redis:
        image: valkey/valkey:9
        restart: unless-stopped
        healthcheck:
          test: ["CMD-SHELL", "valkey-cli ping | grep PONG"]
          interval: 10s
          timeout: 5s
          retries: 5
        networks:
          - internal

      db:
        image: ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0
        restart: unless-stopped
        environment:
          POSTGRES_PASSWORD: "${var.immich_db_password}"
          POSTGRES_USER: immich
          POSTGRES_DB: immich
          POSTGRES_INITDB_ARGS: '--data-checksums'
        volumes:
          - /mnt/tank/immich/db:/var/lib/postgresql/data
        shm_size: 128mb
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -d immich -U immich"]
          interval: 10s
          timeout: 5s
          retries: 5
        networks:
          - internal

    networks:
      proxy:
        name: traefik_proxy
        external: true
      internal:
        driver: bridge
  EOT
}
