# AGENTS.md - Smart Collection Catalog

## Contexto

Servico Rails premium para registro e gerenciamento de colecoes: itens, fotos, autodeteccao local via YOLO, recorte manual, upscale local, compartilhamento publico seguro e exportacao PDF/CSV. Stack principal: Rails 8.1, Ruby 3.3.10, MongoDB/Mongoid, Devise, Hotwire/Turbo/Stimulus, Bootstrap 5, CarrierWave/MiniMagick, Sidekiq/Redis, RSpec e Docker Compose.

## Uso de Contexto

- Antes de abrir arquivos grandes, use `rg` com padroes especificos e leia apenas faixas de linhas relevantes.
- Evite abrir artefatos gerados, minificados, compilados, logs extensos ou dumps completos quando uma busca focada resolver.
- Resuma outputs grandes antes de continuar a investigacao.

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
- Em rotas Rails com `resource :nome_singular`, o controller ainda segue pluralizacao Rails por padrao. Exemplo: `resource :initial_setup` roteia para `InitialSetupsController` e views em `app/views/initial_setups/`. Confirme com `docker compose exec web bin/rails routes -g termo` antes de criar controller/view singular.

## UI, Frontend e i18n

- A UI segue visual premium: paleta existente, glassmorphism, Bootstrap Icons, modais polidos, Grid/List, infinite scroll e transicoes suaves.
- Ao editar views, mantenha responsividade, acessibilidade basica e consistencia com os componentes existentes.
- Ao alterar funcionalidades visiveis de frontend, fluxos Hotwire/Turbo/Stimulus, formularios, modais, navegacao, estados interativos ou responsividade, valide o comportamento com Playwright em navegador real.
- E proibido texto hardcoded em views, controllers, Turbo Streams, JS, toasts, botoes e erros. Use I18n Rails e `config/locales/javascript.*.yml` para textos do JavaScript.
- Stimulus fica em `app/javascript/controllers/`; registre novos controllers em `app/javascript/controllers/index.js`.
- Assets usam jsbundling/cssbundling com esbuild e Propshaft: `npm run build` deve compilar JavaScript e CSS; use `npm run build:js` ou `npm run build:css` apenas para validacoes focadas.

## Docker e Testes

- Rode o projeto via Docker Compose. O `docker-compose.yml` local nao e versionado; use `docker-compose.example.yml` como template.
- Comandos Rails, RSpec e RuboCop devem rodar no container `web`.
- Testes Playwright devem rodar dentro do Docker, no container `web`, com `docker compose exec web npm run test:e2e -- caminho/do/teste.spec.js --browser=chromium`. Use `http://127.0.0.1:3000` quando o teste roda no proprio container `web`.
- RSpec deve usar `docker compose exec web bin/safe_rspec`; nunca rode `bundle exec rspec` direto. O wrapper valida `Rails.env=test` e banco Mongoid com `test` no nome.
- Em falhas de CRLF, timeout ou `Layout/EndOfLine`, aplique o workaround focado documentado em `$quality-check-rails` e registre o resultado parcial sem repetir a mesma etapa indefinidamente.
- Durante a implementacao, rode specs focados no que foi alterado. No fechamento de tarefa Rails relevante, rode a suite suficiente para dar confianca; QA amplo/lint/audit fica para o final do processo ou quando o usuario pedir.
- TDD e esperado: teste antes da implementacao quando houver mudanca de comportamento. Use RSpec, FactoryBot, Shoulda e VCR para HTTP externo.

## Qualidade e Skills

- Use skills de qualidade/seguranca principalmente no fechamento, em pedidos explicitos de QA/audit, ou quando a alteracao tocar fortemente a area da skill.
- A fonte canonica das skills locais fica em `.skills/<nome-da-skill>/SKILL.md`.
- Adaptadores especificos de agentes devem ser wrappers minimos apontando para a fonte canonica. No Codex, cada `.codex/skills/<nome-da-skill>/SKILL.md` deve conter apenas `@../../../.skills/<nome-da-skill>/SKILL.md`.
- Os padroes futuros para agentes genericos (`.agents`) e Claude (`.claude`) devem reutilizar `.skills/` como fonte unica; a adaptacao funcional desses agentes fica para item futuro.
- Rails: use `$quality-check-rails` para QA amplo, lint/testes gerais ou preparacao de CI.
- JavaScript: use `$quality-check-javascript` para mudancas em `app/javascript`, npm, esbuild/jsbundling ou layouts que carregam JS.
- Python: use `$quality-check-python` para mudancas em `yolo/` ou `upscale/`.
- Seguranca: use `$security-check` para auditoria, vulnerabilidades ou correcoes de dependencias vulneraveis.
- Se `brakeman --no-pager` estourar timeout sem retornar resultado, registre o timeout no documento de PR e nao invente status de seguranca verde. Reexecute com timeout maior ou em ambiente externo quando o usuario pedir fechamento de auditoria completo.
- Ao executar uma tarefa originada de plano ou goal, faca no fechamento uma checagem de qualidade proporcional ao codigo alterado antes do commit. Para Rails, rode specs focados via `bin/safe_rspec` e RuboCop focado; para JS, rode lint/build quando alterar `app/javascript` ou assets carregados por JS; para funcionalidades visiveis de frontend, rode Playwright dentro do Docker; para Python/microservicos, rode testes/lint correspondentes em `yolo/` ou `upscale/`; para mudancas sensiveis ou dependencias, rode Brakeman/Bundler Audit quando aplicavel.
- Se o QA amplo (`bin/qa`) estourar timeout ou falhar por CRLF, divida em etapas conforme a secao Docker e Testes, registre o resultado parcial no documento local de PR e nao declare status verde para uma etapa que nao concluiu.
- Commits devem ser atomicos, em portugues, no formato Conventional Commits.
- Ao criar commit, gere ou atualize um arquivo em `docs/` com dados do PR dos commits atuais. A pasta `docs/` e ignorada pelo Git; mantenha os arquivos locais, mas fora do versionamento.

## Imagens, YOLO e Upscale

- Uploads usam CarrierWave, nao ActiveStorage. Uploaders ficam em `app/uploaders/`; fotos sao convertidas para JPG.
- `ImageUpscalerService` centraliza upscale e deve afetar apenas o fluxo/model `Car`. IA depende de `User#ai_upscaling_enabled` e so chama `IMAGE_UPSCALE_SERVICE_URL` quando configurado.
- Minimo por env: `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` (padrao 360) vale para fotos de `Car`.
- Autodeteccao principal, recortes automaticos, recortes manuais e registros de verificacao nao usam upscaler, nem IA nem fallback local. O YOLO deve analisar a foto original enviada.
- O toggle da verificacao de autodeteccao deve ser mantido apenas como preferencia para o `Car` criado receber ou nao upscale quando salvo.
- Preserve limpeza de `Tempfile` e cubra `ImageUpscalerService::UpscaleError` em specs quando alterar fluxo de imagem de `Car`.
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
- Evite pipes do PowerShell ao combinar `docker compose exec` com comandos Unix (`| sed`, `| grep`, etc.), porque o pipe pode ser interpretado no host e falhar. Prefira colocar a pipeline inteira dentro de `sh -lc` no container ou use `wsl.exe sed -n ...` para leituras simples.
- Nem toda imagem Docker do projeto possui utilitarios basicos como `ps`. Para diagnostico de containers, prefira `docker compose ps`, `docker compose logs --tail=N servico` ou comandos especificos disponiveis no container em vez de `docker compose exec web ps ...`.

## Branches, PR e CI

- Branches: `feature/`, `fix/`, `chore/`, `hotfix/`, `test/`, em kebab-case portugues, a partir de `main`.
- No primeiro plano ou goal implementavel de uma sessao, crie um branch novo a partir de `main`, salvo se o usuario pedir explicitamente para usar o branch atual. Para continuacoes do mesmo plano/goal na mesma sessao, mantenha o branch ja criado. Se o usuario disser "neste branch", nao troque de branch.
- CI de PR para `main`: build Docker, RSpec, RuboCop e Bundler Audit. PR com CI vermelho nao deve ser mergeado.
- PRs devem ser pequenos e focados, com descricao do que foi feito, por que e como testar. Ao fechar plano/goal, atualize/crie um arquivo local em `docs/` com resumo, testes, riscos, timeouts e QA parcial antes do commit.
- Checklist de review: escopo por usuario, testes adequados, arquitetura preservada, sem duplicacao desnecessaria, sem secrets e sem dependencias nao autorizadas.
