resource "truenas_app" "traefik" {
  name       = "traefik"
  custom_app = true

  compose_config = <<-EOT
    services:
      traefik:
        image: traefik:v3
        restart: unless-stopped
        ports:
          - "80:80"
          - "443:443"
        environment:
          CLOUDFLARE_DNS_API_TOKEN: "${var.cloudflare_api_token}"
          CLOUDFLARE_ZONE_API_TOKEN: "${var.cloudflare_api_token}"
          CLOUDFLARE_PROPAGATION_TIMEOUT: "3600"
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock:ro
          - acme:/acme
        command:
          - --log.level=INFO
          - --api.dashboard=true
          - --providers.docker=true
          - --providers.docker.network=traefik_proxy
          - --providers.docker.exposedbydefault=false
          - --entrypoints.web.address=:80
          - --entrypoints.web.http.redirections.entrypoint.to=websecure
          - --entrypoints.web.http.redirections.entrypoint.scheme=https
          - --entrypoints.websecure.address=:443
          - --certificatesresolvers.letsencrypt.acme.dnschallenge=true
          - --certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare
          - --certificatesresolvers.letsencrypt.acme.dnschallenge.resolvers=1.1.1.1:53,8.8.8.8:53
          - --certificatesresolvers.letsencrypt.acme.dnschallenge.propagation=true
          - --certificatesresolvers.letsencrypt.acme.dnschallenge.propagation.delaybeforechecks=30s
          - --certificatesresolvers.letsencrypt.acme.dnschallenge.propagation.disableanschecks=true
          - --certificatesresolvers.letsencrypt.acme.email=${var.truenas_cf_email}
          - --certificatesresolvers.letsencrypt.acme.storage=/acme/acme.json
        labels:
          - traefik.enable=true
          - traefik.http.routers.dashboard.rule=Host(`traefik.yuriykovalchuk.dev`)
          - traefik.http.routers.dashboard.entrypoints=websecure
          - traefik.http.routers.dashboard.tls.certresolver=letsencrypt
          - traefik.http.routers.dashboard.service=api@internal
        networks:
          - proxy

    networks:
      proxy:
        name: traefik_proxy

    volumes:
      acme:
  EOT
}
