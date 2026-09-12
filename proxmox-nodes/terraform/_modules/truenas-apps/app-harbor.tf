# Harbor container registry.
#
# Harbor has no supported plain-compose install: upstream generates the component
# configs with the `goharbor/prepare` container and only then writes a compose file
# (goharbor/harbor#22539 was closed as not planned).
#
# prepare cannot run as a service inside this app's own compose: TrueNAS validates
# the compose when creating the app, and `env_file` entries must resolve at that
# point — but those files do not exist until prepare has run. So prepare runs first,
# over SSH, from terraform_data below; the app is only created afterwards.
#
# The compose is derived from
# make/photon/prepare/templates/docker_compose/docker-compose.yml.jinja at v2.15.2,
# with four changes needed to run under ix-apps:
#   1. ./common/config/* rewritten to absolute /mnt/tank/harbor/config/*, since the
#      compose project dir is ix-managed and relative mounts would not resolve.
#   2. The `log` service and every `logging: driver: syslog` block dropped. Those
#      point at the log container on tcp://localhost:1514, and when it is not yet
#      listening the others fail at the daemon level with "failed to initialize
#      logging driver". json-file + `docker logs` is both simpler and more useful.
#   3. container_name removed — upstream hardcodes `registry`, `redis` and `nginx`,
#      which would collide with other apps on this daemon. Harbor's generated
#      configs address peers by compose service name, so nothing breaks.
#   4. No published ports: Traefik owns 80/443, so `proxy` joins traefik_proxy and
#      is routed by label. external_url keeps Harbor from trying to terminate TLS.
#   5. deploy.resources.limits on every service — this VM has 11.4 GiB with no swap
#      shared with Vault, RustFS, Traefik and Dockhand. Ceilings total 2.75 GiB.
#
# Upgrades: bump local.harbor_version and re-apply. That re-triggers prepare (which
# regenerates the configs and preserves the secrets already under data/secret) and
# recreates the app with the new image tags. All goharbor components publish the
# same Harbor tag, so one variable covers every image.

locals {
  harbor_version = "v2.15.2"
  harbor_data    = "/mnt/tank/harbor/data"
  harbor_config  = "/mnt/tank/harbor/config"

  harbor_yml = <<-EOT
    hostname: harbor.yuriykovalchuk.dev

    # Traefik terminates TLS; Harbor serves plain HTTP on 8080 inside the compose
    # network and never publishes a port to the host.
    external_url: https://harbor.yuriykovalchuk.dev
    http:
      port: 8080

    # WRITE-ONCE. Harbor moves this into the database on first install; changing
    # it here afterwards is silently ignored. Rotate it from the UI or the API.
    harbor_admin_password: ${var.harbor_admin_password}

    database:
      # WRITE-ONCE. prepare re-renders config/db/env from this on every run, but
      # the initialised postgres data dir keeps the original password — changing
      # it here leaves core unable to authenticate until the database is rebuilt.
      password: ${var.harbor_db_password}
      max_idle_conns: 100
      max_open_conns: 900
      conn_max_lifetime: 5m
      conn_max_idle_time: 0

    data_volume: ${local.harbor_data}

    trivy:
      ignore_unfixed: false
      skip_update: false
      # trivy-java-db is a separate ~1.5GB download; enable only if you start
      # scanning Java images
      skip_java_db_update: true
      db_repository: ghcr.io/aquasecurity/trivy-db
      java_db_repository: ghcr.io/aquasecurity/trivy-java-db
      offline_scan: false
      security_check: vuln
      insecure: false
      timeout: 5m0s
      # anonymous GitHub is capped at 60 req/hr, which makes DB refreshes fail
      # intermittently and scan results go stale
      github_token: ${var.harbor_trivy_github_token}

    jobservice:
      # 3 shared cores on this VM — upstream default of 10 workers would starve
      # Vault and Traefik during a replication or GC run
      max_job_workers: 3
      max_job_duration_hours: 24
      job_loggers:
        - STD_OUTPUT
      logger_sweeper_duration: 1

    notification:
      webhook_job_max_retry: 3
      webhook_job_http_client_timeout: 3

    log:
      level: info
      local:
        # upstream default is 50 x 200M = up to 10GB of logs
        rotate_count: 5
        rotate_size: 50M
        location: /var/log/harbor

    _version: 2.15.0

    proxy:
      http_proxy:
      https_proxy:
      no_proxy:
      components:
        - core
        - jobservice
        - trivy

    upload_purging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false

    cache:
      enabled: false
      expire_hours: 24
  EOT
}

# Renders harbor.yml and runs goharbor/prepare, which generates every component
# config under harbor_config and the instance secrets under harbor_data/secret.
# Re-runs whenever the version or the rendered config changes; prepare wipes and
# regenerates the config dir but reuses existing secrets, so it is safe to repeat.
resource "terraform_data" "harbor_prepare" {
  triggers_replace = [
    local.harbor_version,
    sha256(local.harbor_yml),
  ]

  connection {
    type        = "ssh"
    host        = var.truenas_host
    user        = "root"
    private_key = var.truenas_ssh_private_key
    # TrueNAS mounts /tmp noexec, so the default script_path there fails with
    # exit 126 (uploaded, not executable). /root carries no such flag.
    script_path = "/root/terraform_provisioner_%RAND%.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",
      "mkdir -p /mnt/tank/harbor/input ${local.harbor_config} /mnt/tank/harbor/compose",
      # Docker would create these as root-owned on first bind mount, and TrueNAS
      # validates that bind sources exist before the app is created.
      "mkdir -p ${local.harbor_data}/registry ${local.harbor_data}/database ${local.harbor_data}/redis ${local.harbor_data}/job_logs ${local.harbor_data}/ca_download ${local.harbor_data}/trivy-adapter/trivy ${local.harbor_data}/trivy-adapter/reports",
      "chown -R 10000:10000 ${local.harbor_data}/registry ${local.harbor_data}/job_logs ${local.harbor_data}/ca_download ${local.harbor_data}/trivy-adapter",
      "chown -R 999:999 ${local.harbor_data}/database ${local.harbor_data}/redis",
      # harbor.yml carries the admin and database passwords
      "install -m 600 /dev/null /mnt/tank/harbor/input/harbor.yml",
      "cat > /mnt/tank/harbor/input/harbor.yml <<'HARBOR_YML'\n${local.harbor_yml}\nHARBOR_YML",
      "docker run --rm --privileged -v /mnt/tank/harbor/input:/input -v ${local.harbor_data}:/data -v /mnt/tank/harbor/compose:/compose_location -v ${local.harbor_config}:/config -v /:/hostfs goharbor/prepare:${local.harbor_version} prepare --with-trivy",
    ]
  }
}

resource "truenas_app" "harbor" {
  name       = "harbor"
  custom_app = true

  depends_on = [terraform_data.harbor_prepare]

  compose_config = <<-EOT
    services:
      registry:
        image: goharbor/registry-photon:${local.harbor_version}
        restart: always
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - SETGID
          - SETUID
        volumes:
          - ${local.harbor_data}/registry:/storage:z
          - ${local.harbor_config}/registry/:/etc/registry/:z
          - type: bind
            source: ${local.harbor_data}/secret/registry/root.crt
            target: /etc/registry/root.crt
          - type: bind
            source: ${local.harbor_config}/shared/trust-certificates
            target: /harbor_cust_cert
        deploy:
          resources:
            limits:
              memory: 256M
        networks:
          - harbor

      registryctl:
        image: goharbor/harbor-registryctl:${local.harbor_version}
        restart: always
        env_file:
          - ${local.harbor_config}/registryctl/env
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - SETGID
          - SETUID
        volumes:
          - ${local.harbor_data}/registry:/storage:z
          - ${local.harbor_config}/registry/:/etc/registry/:z
          - type: bind
            source: ${local.harbor_config}/registryctl/config.yml
            target: /etc/registryctl/config.yml
          - type: bind
            source: ${local.harbor_config}/shared/trust-certificates
            target: /harbor_cust_cert
        deploy:
          resources:
            limits:
              memory: 128M
        networks:
          - harbor

      postgresql:
        image: goharbor/harbor-db:${local.harbor_version}
        restart: always
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - DAC_OVERRIDE
          - SETGID
          - SETUID
        volumes:
          - ${local.harbor_data}/database:/var/lib/postgresql/data:z
        # upstream ships 1gb; tmpfs pages count against the memory limit, and
        # Harbor's schema never needs that much shared memory
        shm_size: '256m'
        deploy:
          resources:
            limits:
              memory: 512M
        networks:
          harbor:

      core:
        image: goharbor/harbor-core:${local.harbor_version}
        restart: always
        env_file:
          - ${local.harbor_config}/core/env
        cap_drop:
          - ALL
        cap_add:
          - SETGID
          - SETUID
        volumes:
          - ${local.harbor_data}/ca_download/:/etc/core/ca/:z
          - ${local.harbor_data}/:/data/:z
          - ${local.harbor_config}/core/certificates/:/etc/core/certificates/:z
          - type: bind
            source: ${local.harbor_config}/core/app.conf
            target: /etc/core/app.conf
          - type: bind
            source: ${local.harbor_data}/secret/core/private_key.pem
            target: /etc/core/private_key.pem
          - type: bind
            source: ${local.harbor_data}/secret/keys/secretkey
            target: /etc/core/key
          - type: bind
            source: ${local.harbor_config}/shared/trust-certificates
            target: /harbor_cust_cert
        deploy:
          resources:
            limits:
              memory: 384M
        networks:
          harbor:
        depends_on:
          - registry
          - redis
          - postgresql

      portal:
        image: goharbor/harbor-portal:${local.harbor_version}
        restart: always
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - SETGID
          - SETUID
          - NET_BIND_SERVICE
        volumes:
          - type: bind
            source: ${local.harbor_config}/portal/nginx.conf
            target: /etc/nginx/nginx.conf
        deploy:
          resources:
            limits:
              memory: 64M
        networks:
          - harbor

      jobservice:
        image: goharbor/harbor-jobservice:${local.harbor_version}
        restart: always
        env_file:
          - ${local.harbor_config}/jobservice/env
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - SETGID
          - SETUID
        volumes:
          - ${local.harbor_data}/job_logs:/var/log/jobs:z
          - type: bind
            source: ${local.harbor_config}/jobservice/config.yml
            target: /etc/jobservice/config.yml
          - type: bind
            source: ${local.harbor_config}/shared/trust-certificates
            target: /harbor_cust_cert
        deploy:
          resources:
            limits:
              memory: 256M
        networks:
          - harbor
        depends_on:
          - core

      redis:
        image: goharbor/valkey-photon:${local.harbor_version}
        restart: always
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - SETGID
          - SETUID
        volumes:
          - ${local.harbor_data}/redis:/var/lib/redis
        deploy:
          resources:
            limits:
              memory: 128M
        networks:
          harbor:

      trivy-adapter:
        image: goharbor/trivy-adapter-photon:${local.harbor_version}
        restart: always
        env_file:
          - ${local.harbor_config}/trivy-adapter/env
        cap_drop:
          - ALL
        volumes:
          - type: bind
            source: ${local.harbor_data}/trivy-adapter/trivy
            target: /home/scanner/.cache/trivy
          - type: bind
            source: ${local.harbor_data}/trivy-adapter/reports
            target: /home/scanner/.cache/reports
          - type: bind
            source: ${local.harbor_config}/shared/trust-certificates
            target: /harbor_cust_cert
        # scans spike while unpacking layers and walking the vuln DB — upstream's
        # own Helm chart is the only component with a real default, at 1Gi
        deploy:
          resources:
            limits:
              memory: 1024M
        networks:
          - harbor
        depends_on:
          - redis

      proxy:
        image: goharbor/nginx-photon:${local.harbor_version}
        restart: always
        cap_drop:
          - ALL
        cap_add:
          - CHOWN
          - SETGID
          - SETUID
          - NET_BIND_SERVICE
        volumes:
          - ${local.harbor_config}/nginx:/etc/nginx:z
          - type: bind
            source: ${local.harbor_config}/shared/trust-certificates
            target: /harbor_cust_cert
        labels:
          - traefik.enable=true
          - traefik.http.routers.harbor.rule=Host(`harbor.yuriykovalchuk.dev`)
          - traefik.http.routers.harbor.entrypoints=websecure
          - traefik.http.routers.harbor.tls.certresolver=letsencrypt
          - traefik.http.services.harbor.loadbalancer.server.port=8080
        deploy:
          resources:
            limits:
              memory: 64M
        networks:
          - harbor
          - proxy
        depends_on:
          - registry
          - core
          - portal

    networks:
      harbor:
      proxy:
        name: traefik_proxy
        external: true
  EOT
}
