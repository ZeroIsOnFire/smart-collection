# AGENTS.md - Smart Collection Catalog

## Contexto

Servico Rails premium para registro e gerenciamento de colecoes: itens, fotos, autodeteccao local via YOLO, recorte manual, upscale local, compartilhamento publico seguro e exportacao PDF/CSV. Stack principal: Rails 7.1+, Ruby 3.3.10, MongoDB/Mongoid, Devise, Hotwire/Turbo/Stimulus, Bootstrap 5, CarrierWave/MiniMagick, Sidekiq/Redis, RSpec e Docker Compose.

## Prioridades Inviolaveis

- Seguranca e segregacao de dados vem primeiro: dados de usuario sempre escopados por `current_user` ou pelo dono publico validado. Nunca use busca global para recursos privados.
- Colecoes sao privadas por padrao. Visao publica exige `sharing_enabled` e `share_token` UUID imprevisivel.
- Nao exponha secrets, tokens, senhas, parametros sensiveis ou logs com credenciais.
- Todo input externo, formulario, parametro de IA ou request deve passar por Strong Parameters/sanitizacao adequada.
- Nao apague dados locais sem pedido explicito: nada de `Mongoid.purge!`, `db:drop`, limpeza em massa, remocao de volumes ou `docker compose down -v` fora do fluxo seguro de testes.

## Arquitetura

- Use MVC com services em `app/services/` para regra de negocio complexa ou reutilizavel.
- Controllers devem ser finos, RESTful quando possivel, delegando para services e respondendo HTML/Turbo Stream.
- Models ficam com validacoes, associacoes, indices/scopes simples e callbacks essenciais.
- Evite dependencias novas. Gems, libs npm ou pacotes Python exigem autorizacao explicita.
- Preserve compatibilidade com Sidekiq/Redis para jobs assincronos.

## UI, Frontend e i18n

- A UI segue visual premium: paleta existente, glassmorphism, Bootstrap Icons, modais polidos, Grid/List, infinite scroll e transicoes suaves.
- Ao editar views, mantenha responsividade, acessibilidade basica e consistencia com os componentes existentes.
- E proibido texto hardcoded em views, controllers, Turbo Streams, JS, toasts, botoes e erros. Use I18n Rails e `config/locales/javascript.*.yml` para textos do JavaScript.
- Stimulus fica em `app/javascript/controllers/`; registre novos controllers em `app/javascript/controllers/index.js`.

## Docker e Testes

- Rode o projeto via Docker Compose. O `docker-compose.yml` local nao e versionado; use `docker-compose.example.yml` como template.
- Comandos Rails, RSpec e RuboCop devem rodar no container `web`.
- RSpec deve usar `docker compose exec web bin/safe_rspec`; nunca rode `bundle exec rspec` direto. O wrapper valida `Rails.env=test` e banco Mongoid com `test` no nome.
- Se `bin/safe_rspec` ou `bin/qa` falhar no container com mensagens como `$'\r': command not found` ou `cannot execute: required file not found`, o problema costuma ser CRLF nos scripts. Use o workaround sem alterar arquivos: `docker compose exec web sh -lc "tr -d '\r' < bin/safe_rspec | bash -s -- spec/caminho_spec.rb"` para specs focados, `docker compose exec web sh -lc "tr -d '\r' < bin/safe_rspec | bash"` para a suite completa e `docker compose exec web sh -lc "tr -d '\r' < bin/qa | bash"` para QA amplo.
- O `bin/qa` com CRLF removido em memoria pode ainda falhar na etapa final porque chama `bin/safe_rspec` diretamente. Quando isso acontecer, registre o resultado parcial do QA e rode a suite separadamente com o workaround acima.
- Se um lote grande de specs estourar timeout da ferramenta, divida em lotes menores por area alterada antes de repetir a suite completa.
- O RuboCop amplo pode reportar `Layout/EndOfLine` em arquivos preexistentes com CRLF. Corrija line endings apenas nos arquivos realmente tocados pela tarefa, salvo pedido explicito para normalizacao global.
- Durante a implementacao, rode specs focados no que foi alterado. No fechamento de tarefa Rails relevante, rode a suite suficiente para dar confianca; QA amplo/lint/audit fica para o final do processo ou quando o usuario pedir.
- TDD e esperado: teste antes da implementacao quando houver mudanca de comportamento. Use RSpec, FactoryBot, Shoulda e VCR para HTTP externo.

## Qualidade e Skills

- Use skills de qualidade/seguranca principalmente no fechamento, em pedidos explicitos de QA/audit, ou quando a alteracao tocar fortemente a area da skill.
- Rails: use `$quality-check-rails` para QA amplo, lint/testes gerais ou preparacao de CI.
- JavaScript: use `$quality-check-javascript` para mudancas em `app/javascript`, npm, esbuild/jsbundling ou layouts que carregam JS.
- Python: use `$quality-check-python` para mudancas em `yolo/` ou `upscale/`.
- Seguranca: use `$security-check-rails` para auditoria, vulnerabilidades ou correcoes de dependencias vulneraveis.
- Commits devem ser atomicos, em portugues, no formato Conventional Commits.
- Ao criar commit, gere ou atualize um arquivo em `docs/` com dados do PR dos commits atuais. A pasta `docs/` e ignorada pelo Git; mantenha os arquivos locais, mas fora do versionamento.

## Imagens, YOLO e Upscale

- Uploads usam CarrierWave, nao ActiveStorage. Uploaders ficam em `app/uploaders/`; fotos sao convertidas para JPG.
- `ImageUpscalerService` centraliza upscale. IA depende de `User#ai_upscaling_enabled` e so chama `IMAGE_UPSCALE_SERVICE_URL` quando configurado.
- Minimos por env: `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` (padrao 360) para itens gerais e `AUTODETECTION_MINIMUM_SIDE` (padrao 1080) para autodeteccao.
- Upload geral nao usa fallback local quando o usuario desabilita IA; autodeteccao sempre deve preparar imagem para YOLO, usando fallback local se necessario.
- Preserve limpeza de `Tempfile` e cubra `ImageUpscalerService::UpscaleError` em specs quando alterar fluxo de imagem.
- YOLO local e preferencial. Nao use label do YOLO como nome/modelo do item; use label generico traduzido.
- Antes de mexer em microservicos, leia `yolo/AGENTS.md` ou `upscale/AGENTS.md`.
- Gotchas YOLO: manter `ULTRALYTICS_OFFLINE=True`, monkeypatch de `torch.load(weights_only=False)` para PyTorch 2.6+ e algoritmo HSV/K-Means de cor.
- Gotchas upscale: endpoint `POST /upscale?minimum_side=<px>` multipart `file`, resposta JPEG; manter monkeypatch de `torch.load`, compatibilidade `torchvision.transforms.functional_tensor` e tiers anti-distorcao.

## Banco, Busca e Compartilhamento

- Toda query privada deve preservar escopo por usuario. Public sharing deve validar token e `sharing_enabled`.
- Text search de carros depende de indice MongoDB atualizado; ao mexer em busca, cubra isolamento por usuario e indices.
- Jobs de processamento de fotos/autodeteccao devem manter estados `pending/completed/error`, Turbo Streams e retries seguros.

## Windows

- Se PowerShell falhar com `windows sandbox: spawn setup refresh`, a falha costuma estar na camada de sandbox; repita o mesmo comando com `sandbox_permissions: "require_escalated"` quando for necessario usar PowerShell.
- Para leitura simples de arquivos, prefira evitar nova aprovacao usando o container: `docker compose exec web sed -n '1,120p' caminho`.
- Fallback secundario para leitura: `wsl.exe sed -n '1,120p' caminho`.
- Nem toda imagem Docker do projeto possui utilitarios basicos como `ps`. Para diagnostico de containers, prefira `docker compose ps`, `docker compose logs --tail=N servico` ou comandos especificos disponiveis no container em vez de `docker compose exec web ps ...`.

## Branches, PR e CI

- Branches: `feature/`, `fix/`, `chore/`, `hotfix/`, `test/`, em kebab-case portugues, a partir de `main`.
- CI de PR para `main`: build Docker, RSpec, RuboCop e Bundler Audit. PR com CI vermelho nao deve ser mergeado.
- PRs devem ser pequenos e focados, com descricao do que foi feito, por que e como testar.
- Checklist de review: escopo por usuario, testes adequados, arquitetura preservada, sem duplicacao desnecessaria, sem secrets e sem dependencias nao autorizadas.
