# AGENTS.md — Smart Collection Catalog (Serviço de Registro de Coleções)

## Visão Geral

Serviço web premium para registro e gerenciamento de coleções variadas. Permite cadastro de coleções e seus itens, compartilhamento público seguro, indexação automática via fotos (YOLO Local / Google Vision API), recorte interativo de imagens e exportação em PDF/CSV. O design é focado em alta fidelidade ("Premium Vibe"), utilizando Glassmorphism e layouts responsivos avançados (Grid/List views).

---

## 🛡️ Segurança em Primeiro Lugar

A segurança e privacidade dos dados do usuário são a principal prioridade deste projeto. 

- **Segregação Rigorosa de Dados**: Nenhum usuário pode ver, editar ou excluir itens de outro usuário. Toda query e ação de controller deve ser escopada via `current_user` (ex: `current_user.cars.find(params[:id])`).
- **Autenticação**: O acesso é protegido via Devise. Ações sensíveis como alteração de senha e e-mail exigem confirmação da senha atual do usuário.
- **Autorização de Compartilhamento**: Coleções são privadas por padrão. A funcionalidade de "Visão Pública" deve ser explicitamente ativada no Dashboard de Configurações, gerando um `share_token` único (UUID) impossível de ser adivinhado.
- **Proteção de Credenciais**: As chaves da Google Vision API **devem ser fornecidas pelo próprio usuário**. O sistema não deve expor logs, parâmetros HTTP ou views que contenham chaves de API, senhas ou tokens sem ofuscação.
- **Sanitização**: Todo input e parâmetro vindo de requests externas, formulários ou da Vision API deve ser higienizado contra XSS e injeções, utilizando o padrão Strong Parameters do Rails.

---

## Stack Tecnológica

| Camada         | Tecnologia                          |
| -------------- | ----------------------------------- |
| Backend        | Ruby on Rails 7.1+                  |
| Banco de dados | MongoDB 7 (via Mongoid)             |
| Frontend       | Hotwire (Turbo + Stimulus)          |
| CSS            | Bootstrap 5 + Premium Custom CSS    |
| UI / UX        | Cropper.js, Fonte Outfit, Ícones BI |
| Testes         | RSpec, FactoryBot, Shoulda, VCR     |
| Storage        | CarrierWave + MiniMagick            |
| Background     | Sidekiq                             |
| Cache/Fila     | Redis                               |
| OCR/Visão      | YOLO11s (Local) + Google Cloud Vision API |
| Upscale IA     | Real-ESRGAN / Lanczos via FastAPI |
| Exportação     | Prawn (PDF), CSV (Ruby stdlib)            |
| i18n           | rails-i18n (pt-BR / en)                   |
| Infraestrutura | Docker + Docker Compose                   |
| Detecção Local | SCC YOLO Service (Python/FastAPI)         |
| Runtime Ruby   | Ruby 3.3.10                               |

---

## Arquitetura e Design System

- **Padrão MVC** com camada extra de **Services** (`app/services/`).
- **Premium Design System**: A aplicação exige um visual impecável. Evite cores genéricas; utilize nossa paleta premium (`--premium-indigo`, `--premium-slate`), *glassmorphism*, modais polidos e transições suaves (`transition: all 0.3s ease`). 
- **Componentes Modernos**: O sistema utiliza *infinite scroll*, visualização alternável (Grade/Lista compacta), recorte manual interativo de imagens na autodetecção e cópia de links para área de transferência via Stimulus.
- Lógica de negócio complexa ou reutilizável **deve** residir em services, nunca em controllers ou models.
- Controllers devem ser finos: recebem a requisição, delegam ao service e respondem em formatos HTML ou Turbo Stream.
- Models contêm apenas validações, associações e scopes.

### Estrutura de Diretórios Relevante

```
app/
├── controllers/
├── models/
├── services/        # Camada de serviços de negócio e API
├── views/           # UI com Turbo Frames e Streams
├── javascript/      # Stimulus controllers (ex: clipboard, view-toggle)
├── assets/
│   └── stylesheets/ # index.css / application.css (Variáveis Premium)
upscale/             # Microserviço de upscaling local (Python/FastAPI)
├── main.py
├── Dockerfile.cpu     # CPU
├── Dockerfile.nvidia  # CUDA/NVIDIA
├── Dockerfile.amd     # ROCm/AMD
└── AGENTS.md
yolo/                # Microserviço de detecção local (Python)
├── main.py
├── Dockerfile
└── AGENTS.md
spec/
├── controllers/
├── models/
├── services/
├── factories/
├── support/
```

---

## Regras de Desenvolvimento

### TDD Obrigatório
1. **Escreva o teste antes da implementação** — nenhum código de produção sem teste correspondente.
2. Use `RSpec` como framework de testes.
3. Factories com `FactoryBot`; matchers com `Shoulda Matchers`.
4. Usar `VCR` para gravar/reproduzir requisições HTTP externas (ex: Google Vision API), evitando chamadas reais nos testes.
5. Cobertura mínima esperada: models, services, controllers (request specs).
6. Mudanças no microserviço `upscale/` devem incluir/ajustar testes em `upscale/test_main.py` e ser verificadas com `python -m unittest upscale/test_main.py` (ou equivalente dentro do container).

### Docker
- O projeto **deve** rodar exclusivamente via Docker Compose.
- O `docker-compose.yml` local não é versionado; o template oficial versionado é `docker-compose.example.yml`.
- Variáveis de ambiente via arquivo `.env` (template em `.env.example`).
- Serviços esperados no ambiente local: `web`, `sidekiq`, `mongodb`, `redis`, `yolo-service` e `upscale-service`.
- O Rails usa `config.active_job.queue_adapter = :sidekiq`; jobs assíncronos devem continuar compatíveis com Sidekiq e Redis.
- Comandos Rails/RSpec/RuboCop devem ser executados dentro do container `web` (ex: `docker compose exec web bundle exec rspec`).

### Uploads e Processamento de Imagens
- O projeto usa **CarrierWave**, não ActiveStorage. Uploaders vivem em `app/uploaders/` e os arquivos são armazenados em `uploads/...`.
- Fotos são convertidas para JPG pelos uploaders para manter compatibilidade com PDF/exportação.
- O `ImageUpscalerService` é o ponto central para upscale. O uso do upscaler por IA é controlado por usuário via `User#ai_upscaling_enabled` (default `true`) e só deve chamar o microserviço quando `IMAGE_UPSCALE_SERVICE_URL` estiver configurado.
- Tamanhos mínimos configuráveis por `.env`: itens gerais usam `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` (padrão `360` px) e autodetecções usam `AUTODETECTION_MINIMUM_SIDE` (padrão `1080` px).
- Uploads gerais de itens não devem usar fallback local quando o usuário desabilitar o upscaler por IA; nesses casos, a foto deve seguir sem chamar o `upscale-service`.
- Uploads de autodetecção devem sempre preservar a preparação para YOLO: se o serviço de IA estiver indisponível ou desabilitado pelo usuário, aplique upscale simples local via MiniMagick/ImageMagick até `AUTODETECTION_MINIMUM_SIDE`.
- A opção de upscaler por IA só deve aparecer na tela de configurações quando o serviço estiver configurado. Ela deve ficar como toggle lateral independente do formulário de perfil/senha, no mesmo padrão da visão pública. Avisos abaixo dos uploads também só aparecem quando o usuário está com IA habilitada e o serviço existe.
- Ao alterar fluxos de imagem, preserve a limpeza de `Tempfile` nos services e cubra erros de `ImageUpscalerService::UpscaleError` em specs.

### Autodetecção e Visão
- **Local (YOLO)**: A aplicação utiliza o `SCC YOLO Service` (YOLO11s) rodando localmente para detecção rápida de carros e localização. Esta é a opção preferencial.
- **Cloud (Vision API)**: As credenciais da Vision API podem ser fornecidas pelo usuário para OCR avançado ou como fallback. Atualmente, o foco de detecção foi migrado para o YOLO local.
- A autodetecção deve criar registros rapidamente a partir de múltiplos veículos na foto, mas não deve preencher nome/modelo a partir do label retornado pelo YOLO; use o label genérico traduzido para novos itens detectados.
- O fluxo conta com *fallback* manual caso o recorte falhe ou seja impreciso, e a interface deve atualizar via WebSockets/Turbo Streams em tempo real.
- **⚠️ Gotchas do Microserviço YOLO**:
  - **PyTorch 2.6+ Crash**: O serviço exige um *monkeypatch* em `torch.load` para forçar `weights_only=False`, evitando a quebra do pacote `ultralytics`.
  - **Offline Mode**: A variável `ULTRALYTICS_OFFLINE=True` é estritamente obrigatória para impedir travamentos de rede no container.
  - **Detecção de Cor**: O serviço não usa ML adicional para cores; utiliza algoritmo de K-Means no espaço HSV em `main.py` para melhor performance.
  - *Consulte o arquivo `yolo/AGENTS.md` para as regras completas do microserviço.*

### Upscale Local (Real-ESRGAN)
- O Rails integra com o `upscale-service` via `IMAGE_UPSCALE_SERVICE_URL` e autentica com `IMAGE_UPSCALE_API_KEY` quando configurada.
- O endpoint principal é `POST /upscale?minimum_side=<px>` com upload multipart `file`; a resposta é JPEG.
- O runtime do serviço e escolhido pelo Dockerfile: `upscale/Dockerfile.cpu`, `upscale/Dockerfile.nvidia` ou `upscale/Dockerfile.amd`.
- O `docker-compose.yml` local deve ficar em CPU por padrao; NVIDIA/AMD exigem troca explicita do Dockerfile e configuracao de dispositivos.
- Gotchas críticos do `upscale/`: manter monkeypatch de `torch.load(weights_only=False)` antes de importar Real-ESRGAN; manter compatibilidade de `torchvision.transforms.functional_tensor`; preservar o sistema de tiers anti-distorção (`TIER_4X_THRESHOLD`, `TIER_2X_THRESHOLD`).
- Consulte `upscale/AGENTS.md` antes de alterar qualquer código do microserviço.

### Frontend e i18n
- JavaScript usa Stimulus via importmap; novos controllers devem seguir o padrão em `app/javascript/controllers/`.
- Textos usados em JavaScript devem vir dos arquivos `config/locales/javascript.*.yml` e da infraestrutura de i18n carregada pela partial `shared/_javascript_i18n.html.erb`.
- Evite texto hardcoded também em Turbo Streams, toasts, botões, labels e mensagens de erro.

### Dependências
- **Não adicionar gems ou bibliotecas novas sem autorização explícita do usuário.**
- Qualquer nova dependência deve ser justificada antes da inclusão.

### CI/CD
- Pull Requests para `main` disparam o pipeline de CI (GitHub Actions).
- O CI executa: build Docker → RSpec → RuboCop → Bundler Audit.
- PRs com testes falhando **não devem** ser mergeados.

### Código Limpo
- Código repetido deve ser extraído para um service.
- Seguir convenções Ruby/Rails (naming, indentação de 2 espaços).
- Controllers com no máximo as 7 actions REST padrão; lógica adicional vai para services.

---

## Convenção de Branches

| Prefixo     | Uso                                      | Exemplo                        |
| ----------- | ---------------------------------------- | ------------------------------ |
| `feature/`  | Nova funcionalidade                      | `feature/cadastro-colecoes`    |
| `fix/`      | Correção de bug                          | `fix/login-redirect`           |
| `chore/`    | Manutenção, refactoring, configs         | `chore/atualizar-rubocop`      |
| `hotfix/`   | Correção urgente em produção             | `hotfix/crash-export-pdf`      |
| `test/`     | Adição ou correção de testes             | `test/service-colecao`         |

- Branch base: sempre a partir de `main`.
- Nomes em **kebab-case**, em **português**, curtos e descritivos.

---

## Convenção de Commits

Formato [Conventional Commits](https://www.conventionalcommits.org/) em português:

```
<tipo>(<escopo>): <descrição curta>

<corpo opcional>
```

### Tipos permitidos

| Tipo       | Quando usar                              |
| ---------- | ---------------------------------------- |
| `feat`     | Nova funcionalidade                      |
| `fix`      | Correção de bug                          |
| `test`     | Adição ou correção de testes             |
| `refactor` | Refatoração sem mudança de comportamento |
| `chore`    | Tarefas de manutenção e configs          |
| `docs`     | Alterações na documentação               |
| `style`    | Formatação, espaços, lint (sem lógica)   |
| `ci`       | Mudanças no pipeline de CI               |

### Exemplos

```
feat(colecoes): adicionar CRUD de coleções
fix(auth): corrigir redirect após login
test(services): adicionar testes do ExportPdfService
refactor(items): extrair lógica de tags para TagService
```

---

## Code Review

### Regras para PRs
1. **Todo código deve passar por review** antes de merge em `main`.
2. O CI deve estar verde (testes + lint + audit) antes da aprovação.
3. PRs devem ser **pequenos e focados** — uma feature ou fix por PR.
4. Descrição do PR deve conter: o que foi feito, por que, e como testar.

### Checklist de Review
- [ ] Segurança primeiro: Segregação de dados garantida (`current_user`)?
- [ ] Testes foram escritos **antes** da implementação (TDD)?
- [ ] Cobertura adequada (models, services, controllers)?
- [ ] Código segue os padrões de arquitetura (MVC + Services)?
- [ ] Sem código duplicado (extraído para service se necessário)?
- [ ] Sem secrets ou API keys expostos?
- [ ] Sem gems/bibliotecas novas não-autorizadas?

---

## Etapas de Desenvolvimento (Ordem Atualizada)

1. [x] Login e Autenticação
2. [x] Cadastro de Usuários e Configurações de Perfil Seguras
3. [x] Cadastro e Gestão de Coleções (Premium Grid/List)
4. [x] Captura/Indexação via Google Vision API e Recorte Interativo
5. [x] Link público e Visão Showcase Privada (Share Token Segregado)
6. [x] Exportação de Coleção para PDF (Prawn)
7. [x] Exportação de Coleção para CSV
8. [x] Pesquisa Global / Full Text Search Integrada (Múltiplas Coleções)
9. **TODO**: Avaliar modelos de monetização e deploy da versão cloud/self-hosted.

---

## Convenções para Agentes

- **PRIORIDADE MÁXIMA**: Segurança e Segregação de Dados (`current_user`).
- **Internacionalização Obrigatória**: É proibido adicionar textos "hardcoded" em views, controllers ou javascript. Tudo deve ser traduzido utilizando a API de I18n do Rails (ex: `t('chave.da.traducao')`).
- Ao criar ou editar views, garanta a adequação ao padrão Premium Design (usando CSS e ícones existentes).
- Sempre execute `docker compose exec web bundle exec rspec` antes de considerar uma tarefa Rails concluída.
- Para alterações em microserviços Python, execute também os testes do respectivo diretório (`upscale/test_main.py` ou testes do `yolo/`, quando existirem).
- Commits devem ser atômicos e com mensagens claras em português.
- **Verificação de Qualidade (QA)**: Sempre que o usuário pedir para verificar a qualidade do projeto (rodar linters/testes), você DEVE ler e assumir a persona descrita em `QUALITY_AGENT.md`.
