# Configuração local do Grafana

Este diretório provisiona a stack local de observabilidade: Grafana,
Prometheus, Loki, Tempo, Grafana Alloy e exporters de MongoDB, Redis, host e
containers.

Para a versão em inglês, veja [README.md](README.md).

## Configuração

1. Crie os arquivos de configuração local:

   ```bash
   cp .env.example .env
   cp docker-compose.example.yml docker-compose.yml
   ```

2. No `.env`, defina uma senha local forte em `GRAFANA_ADMIN_PASSWORD` e ative
   a telemetria:

   ```dotenv
   OBSERVABILITY_ENABLED=true
   RAILS_ALLOWED_HOSTS=localhost,127.0.0.1,web
   ```

3. Suba a aplicação e o perfil de observabilidade:

   ```bash
   docker compose --profile observability up -d --build
   ```

4. Abra o Grafana em `http://127.0.0.1:3001` (ou `GRAFANA_PORT`) e entre com
   `GRAFANA_ADMIN_USER` e `GRAFANA_ADMIN_PASSWORD`.

## Sinais incluídos

- O Prometheus coleta métricas de Rails, YOLO, Upscale, MongoDB, Redis,
  cAdvisor e node-exporter.
- O Alloy envia logs Docker ao Loki com labels `service`, `container` e
  `environment`.
- Rails e Sidekiq exportam traces OTLP/HTTP ao Alloy na porta `4318`; YOLO e
  Upscale usam OTLP/gRPC na porta `4317`. O Alloy encaminha os traces ao Tempo.

## Segurança e produção

- O Grafana é vinculado a `127.0.0.1`; os backends de observabilidade não
  publicam portas no host.
- Não exponha `/metrics` em um proxy público. O Prometheus o acessa pela rede
  Docker, usando o hostname `web`.
- Em produção, defina `RAILS_ALLOWED_HOSTS` com os domínios públicos da
  aplicação e o hostname interno do Prometheus, como `web`.
- Use credenciais próprias de produção no Grafana e mantenha os volumes nomeados.
