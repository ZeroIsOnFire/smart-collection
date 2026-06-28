# Smart Collection Catalog

[Read in English](README.md)

O **Smart Collection Catalog** é um serviço Rails premium para registro e gerenciamento de coleções privadas, focado inicialmente em miniaturas de carros. O sistema permite cadastro manual, preparação local de imagens com IA, autodetecção com YOLO, compartilhamento público seguro e exportação em PDF/CSV.

## Tecnologias

- **Backend**: Ruby on Rails 8.1
- **Banco de dados**: MongoDB 7 com Mongoid
- **Autenticação**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus) e Bootstrap 5
- **Tempo real**: Action Cable via Redis
- **Jobs em background**: Sidekiq
- **IA local**: detecção YOLO11s e upscale Real-ESRGAN
- **Infraestrutura**: Docker e Docker Compose

## Configuração

### Requisitos

- Docker e Docker Compose

### Instalação

1. Clone o repositório:

   ```bash
   git clone <repo-url>
   cd smart-collection
   ```

2. Crie o arquivo de ambiente a partir do template:

   ```bash
   cp .env.example .env
   ```

3. Suba os containers:

   ```bash
   docker compose up -d --build
   ```

4. Popule o banco:

   ```bash
   docker compose exec web bin/rails db:seed
   ```

5. Acesse a aplicação:

   ```text
   http://localhost:3000
   ```

## Locale

A aplicação possui arquivos de locale em português (`pt-BR`) e inglês (`en`). O português é o locale padrão atual em tempo de execução em `config/initializers/locale.rb`.

## Funcionalidades principais

- **Coleções privadas por padrão**: dados de usuário permanecem escopados ao dono autenticado.
- **Autodetecção por IA**: envie uma foto com vários itens e deixe o YOLO local detectar, recortar e montar a fila de revisão.
- **Gestão de acervo**: controle marca, nome, ano, escala, cor, fotos e metadados de cada item.
- **Preparação de imagens**: upscale local opcional prepara fotos de carros para salvamento final.
- **Feedback em tempo real**: estados de processamento e atualizações de interface usam Turbo Streams.
- **Compartilhamento público seguro**: coleções podem ser compartilhadas apenas com token público explícito e compartilhamento habilitado.
- **Exportações**: gere relatórios PDF e CSV da coleção.

## Microserviços

O projeto inclui microserviços locais de IA executados pelo Docker Compose:

- `yolo-service`: detecção local YOLO11s e classificação simples de cor para fluxos de autodetecção. Veja [`yolo/README.md`](yolo/README.md).
- `upscale-service`: serviço local de upscale/preparação de imagem usado por uploads de fotos de carros. O setup Docker padrão usa `upscale/Dockerfile.cpu`; veja [`upscale/README.md`](upscale/README.md).

Os limites de preparação de imagem são configurados no `.env` com `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` para fotos de carros.

## Testes

Rode a suíte Rails pelo wrapper seguro:

```bash
docker compose exec web bin/safe_rspec
```

O wrapper valida que o ambiente de teste está ativo antes de executar o RSpec.

## Licença

Este projeto é de uso privado. Siga as regras do repositório em [`AGENTS.md`](AGENTS.md).
