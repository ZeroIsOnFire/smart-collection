# Smart Collection Catalog (Serviço de Registro de Coleções)

O **Smart Collection Catalog** é um serviço web premium para registro e gerenciamento de coleções variadas (focado inicialmente em miniaturas de carros). O sistema permite o cadastro manual ou automatizado através de inteligência artificial (Google Cloud Vision API).

## 🚀 Tecnologias

- **Backend**: Ruby on Rails 7.1+
- **Banco de Dados**: MongoDB 7 (via Mongoid)
- **Frontend**: Hotwire (Turbo + Stimulus) + Bootstrap 5
- **Real-time**: ActionCable (via Redis)
- **Mensageria**: Sidekiq
- **IA/Visão**: Google Cloud Vision API
- **Infraestrutura**: Docker + Docker Compose

## 🛠️ Configuração e Instalação

### Pré-requisitos
- Docker e Docker Compose instalados.

### Passo a Passo

1. **Clone o repositório**:
   ```bash
   git clone <repo-url>
   cd smart-collection
   ```

2. **Configuração de Ambiente**:
   Crie um arquivo `.env` na raiz do projeto (use o `.env.example` como base):
   ```bash
   GOOGLE_CLOUD_PROJECT_ID=seu-projeto
   GOOGLE_CLOUD_CREDENTIALS_PATH=/app/config/google_credentials.json
   REDIS_URL=redis://redis:6379/1
   ```

3. **Suba os containers**:
   ```bash
   docker-compose up -d --build
   ```

4. **Preparação do Banco**:
   ```bash
   docker-compose exec web bin/rails db:seed
   ```

5. **Acesse a aplicação**:
   Abra `http://localhost:3000` no seu navegador.

## 🧠 Funcionalidades Principais

- **Autodetecção via IA**: Faça o upload de uma foto com várias miniaturas; a IA irá detectá-las, recortá-las e gerar uma fila de verificação para você catalogar tudo em segundos.
- **Gestão de Acervo**: Controle marca, fabricante, nome, ano, escala e cor de cada item.
- **Sincronização em Tempo Real**: Status de processamento e atualizações de interface via Turbo Streams.
- **Página de Exibição Pública**: Compartilhe sua coleção através de um link público elegante com busca integrada e rolagem infinita.
- **Design Premium**: Interface moderna com modo lista/grade, animações suaves e foco na usabilidade.

## 🧪 Testes

Para rodar a suite de testes (RSpec):
```bash
docker-compose exec web bundle exec rspec
```

## ⚖️ Licença

Este projeto é de uso privado e segue as diretrizes estabelecidas no documento `AGENTS.md`.
## Image Upscaler

The project uses a dedicated Docker upscaler service.

- General item flows use `ImageUpscalerService::DEFAULT_MINIMUM_SIDE`.
- Autodetection creation uses `AutodetectionService::AUTODETECTION_MINIMUM_SIDE`.
- The service preserves aspect ratio and guarantees the requested minimum side.
- Runtime is selected by the upscale Dockerfile.
- CPU is the local default in `docker-compose.yml` via `upscale/Dockerfile.cpu`.
- NVIDIA uses `upscale/Dockerfile.nvidia`; AMD/ROCm uses `upscale/Dockerfile.amd`.

Environment variables:

- `IMAGE_UPSCALE_SERVICE_URL`: internal URL used by Rails to call the service.
- `IMAGE_UPSCALE_API_KEY`: shared API key for the service, if enabled.
- `REAL_ESRGAN_MODEL_PATH`: optional custom model path inside the selected container.
- `REAL_ESRGAN_DENOISE_STRENGTH`: CPU `realesr-general-x4v3` denoise strength from `0` to `1`; default is `0`.
- `TIER_4X_THRESHOLD` / `TIER_2X_THRESHOLD`: choose Real-ESRGAN 4x, Real-ESRGAN 2x, or Lanczos tiers.
