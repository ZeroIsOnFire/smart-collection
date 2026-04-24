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
