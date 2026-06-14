# Smart Collection Catalog

[Read in English](README.md)

O **Smart Collection Catalog** e um servico Rails premium para registro e gerenciamento de colecoes privadas, focado inicialmente em miniaturas de carros. O sistema permite cadastro manual, preparacao local de imagens com IA, autodeteccao com YOLO, compartilhamento publico seguro e exportacao em PDF/CSV.

## Tecnologias

- **Backend**: Ruby on Rails 8.1
- **Banco de dados**: MongoDB 7 com Mongoid
- **Autenticacao**: Devise
- **Frontend**: Hotwire (Turbo + Stimulus) e Bootstrap 5
- **Tempo real**: Action Cable via Redis
- **Jobs em background**: Sidekiq
- **IA local**: deteccao YOLO11s e upscale Real-ESRGAN
- **Infraestrutura**: Docker e Docker Compose

## Configuracao

### Requisitos

- Docker e Docker Compose

### Instalacao

1. Clone o repositorio:

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

5. Acesse a aplicacao:

   ```text
   http://localhost:3000
   ```

## Locale

A aplicacao possui locales em portugues (`pt-BR`) e ingles (`en`). O portugues e o locale padrao atual em `config/initializers/locale.rb`.

Para usar o sistema em ingles durante o desenvolvimento, acesse as paginas com `?locale=en` quando o fluxo do controller suportar troca de locale, ou altere o locale padrao para `:en` em `config/initializers/locale.rb` no ambiente local.

## Funcionalidades principais

- **Colecoes privadas por padrao**: dados de usuario permanecem escopados ao dono autenticado.
- **Autodeteccao por IA**: envie uma foto com varios itens e deixe o YOLO local detectar, recortar e montar a fila de revisao.
- **Gestao de acervo**: controle marca, nome, ano, escala, cor, fotos e metadados de cada item.
- **Preparacao de imagens**: upscale local opcional prepara fotos para salvamento final e autodeteccao.
- **Feedback em tempo real**: estados de processamento e atualizacoes de interface usam Turbo Streams.
- **Compartilhamento publico seguro**: colecoes podem ser compartilhadas apenas com token publico explicito e compartilhamento habilitado.
- **Exportacoes**: gere relatorios PDF e CSV da colecao.

## Microservicos

O projeto inclui microservicos locais de IA executados pelo Docker Compose:

- `yolo-service`: deteccao local YOLO11s e classificacao simples de cor para fluxos de autodeteccao. Veja [`yolo/README.md`](yolo/README.md).
- `upscale-service`: servico local de upscale/preparacao de imagem usado por uploads de itens e autodeteccao. O setup Docker padrao usa `upscale/Dockerfile.cpu`; veja [`upscale/README.md`](upscale/README.md).

Os limites de preparacao de imagem sao configurados no `.env` com `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` para fotos comuns de itens e `AUTODETECTION_MINIMUM_SIDE` para fotos de autodeteccao. O padrao da autodeteccao e 800 px para reduzir o custo antes do YOLO.

## Testes

Rode a suite Rails pelo wrapper seguro:

```bash
docker compose exec web bin/safe_rspec
```

O wrapper valida que o ambiente de teste esta ativo antes de executar o RSpec.

## Licenca

Este projeto e de uso privado. Siga as regras do repositorio em [`AGENTS.md`](AGENTS.md).
