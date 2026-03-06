# AGENTS.md — Smart Collection Catalog (Serviço de Registro de Coleções)

## Visão Geral

Serviço web para registro e gerenciamento de coleções variadas. Permite cadastro de coleções e seus itens, compartilhamento, indexação automática via fotos (Google Vision API — credenciais fornecidas pelo usuário) e exportação em PDF/CSV.

---

## Stack Tecnológica

| Camada         | Tecnologia                          |
| -------------- | ----------------------------------- |
| Backend        | Ruby on Rails 7.1+                  |
| Banco de dados | MongoDB 7 (via Mongoid)             |
| Frontend       | Hotwire (Turbo + Stimulus)          |
| CSS            | Bootstrap 5                         |
| Testes         | RSpec, FactoryBot, Shoulda, VCR     |
| Storage        | ActiveStorage                       |
| Background     | Solid Queue                         |
| Cache          | Solid Cache                         |
| OCR/Visão      | Google Cloud Vision API (user-key)  |
| Exportação     | Prawn (PDF), CSV (Ruby stdlib)      |
| i18n           | rails-i18n (pt-BR / en)             |
| Infraestrutura | Docker + Docker Compose             |

---

## Arquitetura

- **Padrão MVC** com camada extra de **Services** (`app/services/`).
- Lógica de negócio complexa ou reutilizável **deve** residir em services, nunca em controllers ou models.
- Controllers devem ser finos: recebem a requisição, delegam ao service e respondem.
- Models contêm apenas validações, associações e scopes.

### Estrutura de Diretórios Relevante

```
app/
├── controllers/
├── models/
├── services/        # Camada de serviços
├── views/
├── javascript/      # Stimulus controllers
├── assets/
│   └── stylesheets/
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

### Segurança
- Autenticação via Devise.
- Nunca expor secrets ou API keys no código — usar variáveis de ambiente.
- Sanitizar inputs do usuário.
- Validar permissões de acesso (autorização) em cada action.

### Google Vision API
- As credenciais da Vision API **devem ser fornecidas pelo próprio usuário** via variáveis de ambiente (`GOOGLE_CLOUD_PROJECT_ID`, `GOOGLE_CLOUD_CREDENTIALS_PATH`).
- A aplicação **não** possui chave própria da API — o usuário é responsável por criar e configurar seu projeto no Google Cloud.
- A funcionalidade de visão deve degradar graciosamente quando as credenciais não estiverem configuradas.

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
- [ ] Testes foram escritos **antes** da implementação (TDD)?
- [ ] Cobertura adequada (models, services, controllers)?
- [ ] Código segue os padrões de arquitetura (MVC + Services)?
- [ ] Sem código duplicado (extraído para service se necessário)?
- [ ] Sem secrets ou API keys expostos?
- [ ] Sem gems/bibliotecas novas não-autorizadas?

---

## Etapas de Desenvolvimento (Ordem)

1. Login e Autenticação
2. Cadastro de Usuários
3. Cadastro de Coleções
4. Cadastro de Itens de Coleção
5. Exportação de Coleção para PDF (Prawn)
6. Exportação de Coleção para CSV
7. Captura/Indexação de Itens via Google Vision API (credenciais do usuário)
8. Link público / Exportação HTML de coleções (para auto-hospedagem)
9. **TODO**: Avaliar modelos de monetização (ex: cobrar pelo Vision API integrado na versão web, versão self-hosted gratuita com API própria do usuário, planos pagos para remover necessidade de fornecer chave própria)

---

## Convenções para Agentes

- Ao criar novos arquivos, siga estritamente a estrutura de diretórios acima.
- Sempre execute `bundle exec rspec` antes de considerar uma tarefa concluída.
- Mantenha o `README.md` atualizado com qualquer mudança significativa de setup.
- Commits devem ser atômicos e com mensagens claras em português.
