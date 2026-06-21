resource "truenas_app" "zot" {
  name       = "zot"
  custom_app = true

  compose_config = <<-EOT
    services:
      zot:
        image: ghcr.io/project-zot/zot-linux-amd64:latest
        restart: unless-stopped
        command:
          - serve
          - /etc/zot/config.json
        volumes:
          - /mnt/tank/zot:/var/lib/registry
        configs:
          - source: zot-config
            target: /etc/zot/config.json
        labels:
          - traefik.enable=true
          - traefik.http.routers.zot.rule=Host(`zot.yuriykovalchuk.dev`)
          - traefik.http.routers.zot.entrypoints=websecure
          - traefik.http.routers.zot.tls.certresolver=letsencrypt
          - traefik.http.services.zot.loadbalancer.server.port=5000
        deploy:
          resources:
            limits:
              cpus: '2.0'
              memory: 2G
        networks:
          - proxy

    configs:
      zot-config:
        content: |
          {
            "distSpecVersion": "1.1.0",
            "storage": { "rootDirectory": "/var/lib/registry" },
            "http": { "address": "0.0.0.0", "port": "5000" },
            "log": { "level": "warn" },
            "extensions": {
              "search": {
                "enable": true,
                "cve": {
                  "updateInterval": "2h"
                }
              },
              "ui": {
                "enable": true
              },
              "sync": {
                "enable": true,
                "registries": [
                  {
                    "urls": ["https://index.docker.io"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/dockerhub" }]
                  },
                  {
                    "urls": ["https://ghcr.io"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/ghcr" }]
                  },
                  {
                    "urls": ["https://gcr.io"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/gcr" }]
                  },
                  {
                    "urls": ["https://registry.k8s.io"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/k8s" }]
                  },
                  {
                    "urls": ["https://quay.io"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/quay" }]
                  },
                  {
                    "urls": ["https://public.ecr.aws"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/ecr-public" }]
                  },
                  {
                    "urls": ["https://mcr.microsoft.com"],
                    "onDemand": true,
                    "tlsVerify": true,
                    "content": [{ "prefix": "**", "destination": "/mcr" }]
                  }
                ]
              }
            }
          }

    networks:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
