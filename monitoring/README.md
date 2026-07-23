# Grafana local setup

This directory provisions the local observability stack: Grafana, Prometheus,
Loki, Tempo, Grafana Alloy, and MongoDB, Redis, host, and container exporters.

For the Portuguese version, see [README.pt-BR.md](README.pt-BR.md).

## Setup

1. Create local configuration files:

   ```bash
   cp .env.example .env
   cp docker-compose.example.yml docker-compose.yml
   ```

2. In `.env`, set a strong local `GRAFANA_ADMIN_PASSWORD` and enable telemetry:

   ```dotenv
   OBSERVABILITY_ENABLED=true
   RAILS_ALLOWED_HOSTS=localhost,127.0.0.1,web
   ```

3. Start the application and observability profile:

   ```bash
   docker compose --profile observability up -d --build
   ```

4. Open Grafana at `http://127.0.0.1:3001` (or `GRAFANA_PORT`) and sign in with
   `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD`.

## Included signals

- Prometheus scrapes Rails, YOLO, Upscale, MongoDB, Redis, cAdvisor, and
  node-exporter metrics.
- Alloy sends Docker logs to Loki with `service`, `container`, and `environment`
  labels.
- Rails and Sidekiq export OTLP/HTTP traces to Alloy on port `4318`; YOLO and
  Upscale export OTLP/gRPC traces on port `4317`. Alloy forwards traces to Tempo.

## Security and production

- Grafana is bound to `127.0.0.1`; observability backends do not publish host
  ports.
- Do not expose `/metrics` through a public proxy. Prometheus reaches it over
  the Docker network using the `web` hostname.
- In production, set `RAILS_ALLOWED_HOSTS` to the public application domains
  plus the internal Prometheus hostname, such as `web`.
- Use production-specific Grafana credentials and persist the named volumes.
