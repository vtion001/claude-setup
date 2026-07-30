---
name: ags-dev
description: Start or stop the local AGS development environment (Docker stacks). Invoke when user says "start dev", "bring up local", "spin up the stack", "start monitoring", "start observability", "stop everything", "bring down docker", or asks to start/stop any specific stack (observability, quality, cicd, sentry).
---

# AGS Dev Environment

## What to do

**Starting stacks:**
```bash
python3 /mnt/d/ags-dev-os/agsdev.py up observability   # Prometheus + Grafana + Loki + Jaeger
python3 /mnt/d/ags-dev-os/agsdev.py up quality         # SonarQube
python3 /mnt/d/ags-dev-os/agsdev.py up cicd            # Jenkins + Drone
python3 /mnt/d/ags-dev-os/agsdev.py up                 # All stacks
```

**Stopping stacks:**
```bash
python3 /mnt/d/ags-dev-os/agsdev.py down observability
python3 /mnt/d/ags-dev-os/agsdev.py down               # All stacks
```

**bob-ags local dev** (NOT managed by agsdev — run from apps/bob-ags):
```bash
cd /mnt/d/ags-dev-os/apps/bob-ags
npm run dev              # Concurrent: Vite + serve + queue worker
php artisan test         # All tests
```

## Stack prerequisites

- **quality (SonarQube):** needs `sudo sysctl -w vm.max_map_count=524288` first (or add to `/etc/sysctl.d/99-sonarqube.conf`)
- **cicd (Drone):** needs GitHub OAuth app credentials in `stacks/cicd/.env` (DRONE_GITHUB_CLIENT_ID / DRONE_GITHUB_CLIENT_SECRET)
- **sentry:** run `stacks/sentry/install.sh` once before first `up`

## Access after start

- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- Jaeger: http://localhost:16686
- SonarQube: http://localhost:9001 (admin/admin)
- Jenkins: http://localhost:8080 (admin/admin123!)
