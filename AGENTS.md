# AGENTS.md — Smart Collection Catalog (Serviço de Registro de Coleções)

## Visão Geral

Serviço web premium para registro e gerenciamento de coleções variadas. Permite cadastro de coleções e seus itens, compartilhamento público seguro, indexação automática via fotos (Google Vision API — credenciais fornecidas pelo usuário), recorte interativo de imagens e exportação em PDF/CSV. O design é focado em alta fidelidade ("Premium Vibe"), utilizando Glassmorphism e layouts responsivos avançados (Grid/List views).

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
| Storage        | ActiveStorage                       |
| Background     | Solid Queue                         |
| Cache          | Solid Cache                         |
| OCR/Visão      | Google Cloud Vision API (user-key)  |
| Exportação     | Prawn (PDF), CSV (Ruby stdlib)      |
| i18n           | rails-i18n (pt-BR / en)             |
| Infraestrutura | Docker + Docker Compose             |

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

### Docker
- O projeto **deve** rodar exclusivamente via Docker Compose.
- Toda configuração de ambiente está centralizada no `docker-compose.yml`.
- Variáveis de ambiente via arquivo `.env` (template em `.env.example`).

### Autodetecção e Visão
- As credenciais da Vision API **devem ser fornecidas pelo próprio usuário** via variáveis de ambiente (`GOOGLE_CLOUD_PROJECT_ID`, `GOOGLE_CLOUD_CREDENTIALS_PATH`).
- A aplicação **não** possui chave própria da API.
- O fluxo conta com *fallback* manual caso o recorte falhe ou seja impreciso, e a interface deve atualizar via WebSockets/Turbo Streams em tempo real.

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
- Ao criar ou editar views, garanta a adequação ao padrão Premium Design (usando CSS e ícones existentes).
- Sempre execute `bundle exec rspec` antes de considerar uma tarefa concluída.
- Commits devem ser atômicos e com mensagens claras em português.
