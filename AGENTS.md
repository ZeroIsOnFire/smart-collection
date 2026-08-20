# AGENTS.md - Smart Collection Catalog

## Context

Premium Rails service for registering and managing private collections: items, photos, local YOLO autodetection, manual cropping, local upscaling, secure public sharing, wishlist management, and PDF/CSV exports. Main stack: Rails 8.1, Ruby 3.3.10, MongoDB/Mongoid, Devise, Hotwire/Turbo/Stimulus, Bootstrap 5, CarrierWave/MiniMagick, Sidekiq/Redis, RSpec, Playwright, and Docker Compose.

## Context Usage

- Before opening large files, use `rg` with specific patterns and read only the relevant line ranges.
- Avoid opening generated, minified, compiled, long log, or full dump artifacts when a focused search is enough.
- Summarize large outputs before continuing the investigation.
- When repeating a failed command, change the hypothesis, scope, or environment and record the likely cause of the failure.
- Prefer filtered commands to validate the observed symptom; increase timeouts only when there is a concrete reason.

## Inviolable Priorities

- Security and data segregation come first: user data must always be scoped through `current_user` or through a validated public owner. Never use global lookup for private resources.
- Collections are private by default. Public views require `sharing_enabled` and an unpredictable UUID `share_token`.
- Do not expose secrets, tokens, passwords, sensitive parameters, or credential-bearing logs.
- Every external input, form parameter, AI parameter, or request must go through Strong Parameters or appropriate sanitization.
- Do not delete local data without an explicit request: no `Mongoid.purge!`, `db:drop`, mass cleanup, volume removal, or `docker compose down -v` outside a safe test flow.

## Architecture

- Use MVC with services in `app/services/` for complex or reusable business rules.
- Controllers should stay thin, RESTful when possible, delegate to services, and respond with HTML/Turbo Stream.
- Models should hold validations, associations, simple indexes/scopes, and essential callbacks.
- Avoid new dependencies. Gems, npm libraries, or Python packages require explicit authorization.
- Preserve Sidekiq/Redis compatibility for asynchronous jobs.
- In Rails routes declared with singular `resource :singular_name`, the controller still follows Rails pluralization by default. Example: `resource :initial_setup` routes to `InitialSetupsController` and views in `app/views/initial_setups/`. Confirm with `docker compose exec web bin/rails routes -g term` before creating a singular controller/view.

## UI, Frontend, And i18n

- The UI follows the existing premium visual language: current palette, glassmorphism, Bootstrap Icons, polished modals, grid/list views, infinite scroll, and smooth transitions.
- When editing views, preserve responsiveness, basic accessibility, and consistency with existing components.
- When changing visible frontend functionality, Hotwire/Turbo/Stimulus flows, forms, modals, navigation, interactive states, or responsiveness, validate behavior with Playwright in a real browser.
- Hardcoded text is forbidden in views, controllers, Turbo Streams, JavaScript, toasts, buttons, and errors. Use Rails I18n and `config/locales/javascript.*.yml` for JavaScript text.
- Stimulus controllers live in `app/javascript/controllers/`; register new controllers in `app/javascript/controllers/index.js`.
- Assets use jsbundling/cssbundling with esbuild and Propshaft: `npm run build` must compile JavaScript and CSS; use `npm run build:js` or `npm run build:css` only for focused validation.

## Docker And Tests

- Run the project through Docker Compose. The local `docker-compose.yml` is not versioned; use `docker-compose.example.yml` as the template.
- Rails, RSpec, and RuboCop commands must run in the `web` container.
- Playwright tests must run inside Docker, in the `web` container, with `docker compose exec web npm run test:e2e -- path/to/test.spec.js --browser=chromium`. Use `http://127.0.0.1:3000` when the test runs from the `web` container.
- For E2E validation, use Playwright; if no Playwright configuration or versioned scenario exists, validate the scenario through Docker instead of skipping browser coverage.
- RSpec must use `docker compose exec web bin/safe_rspec`; never run `bundle exec rspec` directly. The wrapper validates `Rails.env=test` and a Mongoid database name containing `test`.
- For CRLF, timeout, or `Layout/EndOfLine` failures, apply the focused workaround documented in `$quality-check-rails` and record the partial result instead of repeating the same step indefinitely.
- During implementation, run focused specs for the changed area. For relevant Rails work, finish with a suite broad enough to give confidence; broad QA, lint, and audit are final-stage checks or explicit user requests.
- TDD is expected when behavior changes. Use RSpec, FactoryBot, Shoulda, and VCR for external HTTP.

## Quality And Skills

- Use quality/security skills mainly at closing, for explicit QA/audit requests, or when a change strongly touches a skill's area.
- The canonical source for local skills is `.skills/<skill-name>/SKILL.md`.
- Agent-specific adapters should be minimal wrappers pointing to the canonical source. In Codex, each `.codex/skills/<skill-name>/SKILL.md` must contain only `@../../../.skills/<skill-name>/SKILL.md`.
- Future generic-agent (`.agents`) and Claude (`.claude`) patterns should reuse `.skills/` as the single source of truth; functional adaptation for those agents is future work.
- Rails: use `$quality-check-rails` for broad QA, general lint/tests, or CI preparation.
- JavaScript: use `$quality-check-javascript` for changes in `app/javascript`, npm, esbuild/jsbundling, or layouts that load JavaScript.
- Python: use `$quality-check-python` for changes in `yolo/` or `upscale/`.
- Security: use `$security-check` for audits, vulnerabilities, or vulnerable dependency fixes.
- If `brakeman --no-pager` times out without returning a result, record the timeout in the PR document and do not invent a green security status. Rerun with a longer timeout or in an external environment when the user asks for a complete audit closeout.
- When executing a task from a plan or goal, close with a quality check proportional to the changed code before committing. For Rails, run focused specs through `bin/safe_rspec` and focused RuboCop; for JS, run lint/build when changing `app/javascript` or JS-loaded assets; for visible frontend functionality, run Playwright inside Docker; for Python/microservices, run the corresponding tests/lint in `yolo/` or `upscale/`; for sensitive changes or dependencies, run Brakeman/Bundler Audit when applicable.
- If broad QA (`bin/qa`) times out or fails because of CRLF, split it into steps as described in Docker And Tests, record the partial result in the local PR document, and do not declare a green status for a step that did not finish.
- Commits must be atomic, in Portuguese, and use Conventional Commits.
- When creating a commit, generate or update a local `.md` file under `docs/` following `.github/pull_request_template.md`: use the sections `Resumo`, `Alterações`, `Validação`, and `Observações`. The `docs/` directory is ignored by Git; keep those files local and unversioned.

## Images, YOLO, And Upscale

- Uploads use CarrierWave, not ActiveStorage. Uploaders live in `app/uploaders/`; photos are converted to JPG.
- `ImageUpscalerService` centralizes upscaling and must affect only the `Car` flow/model. AI depends on `User#ai_upscaling_enabled` and calls `IMAGE_UPSCALE_SERVICE_URL` only when configured.
- Environment minimum: `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` (default `360`) applies to `Car` photos.
- Main autodetection, automatic crops, manual crops, and verification records do not use the upscaler, AI, or local fallback. YOLO must analyze the original uploaded photo.
- The autodetection verification toggle must remain only a preference for whether the created `Car` receives upscaling when saved.
- Preserve `Tempfile` cleanup and cover `ImageUpscalerService::UpscaleError` in specs when changing the `Car` image flow.
- Local YOLO is preferred. Do not use the YOLO label as the item name/model; use a translated generic label.
- Before changing microservices, read `yolo/AGENTS.md` or `upscale/AGENTS.md`.
- YOLO gotchas: keep `ULTRALYTICS_OFFLINE=True`, the `torch.load(weights_only=False)` monkeypatch for PyTorch 2.6+, and the HSV/K-Means color algorithm.
- Upscale gotchas: endpoint `POST /upscale?minimum_side=<px>` receives multipart `file` and returns JPEG; keep the `torch.load` monkeypatch, `torchvision.transforms.functional_tensor` compatibility shim, and anti-distortion tiers.

## Database, Search, And Sharing

- Every private query must preserve user scoping. Public sharing must validate the token and `sharing_enabled`.
- Car text search depends on an updated MongoDB index; when changing search, cover user isolation and indexes.
- Photo/autodetection processing jobs must preserve `pending/completed/error` states, Turbo Streams, and safe retries.

## Windows

- If PowerShell fails with `windows sandbox: spawn setup refresh`, the failure is usually in the sandbox layer; repeat the same command with `sandbox_permissions: "require_escalated"` when PowerShell is necessary.
- For simple file reads, prefer avoiding new approval by using the container: `docker compose exec web sed -n '1,120p' path`.
- Secondary read fallback: `wsl.exe sed -n '1,120p' path`.
- Avoid PowerShell pipes when combining `docker compose exec` with Unix commands (`| sed`, `| grep`, etc.), because the pipe may be interpreted on the host and fail. Prefer putting the entire pipeline inside `sh -lc` in the container or use `wsl.exe sed -n ...` for simple reads.
- Not every project Docker image has basic utilities like `ps`. For container diagnostics, prefer `docker compose ps`, `docker compose logs --tail=N service`, or service-specific commands available in the container instead of `docker compose exec web ps ...`.

## Branches, PRs, And CI

- Branches: `feature/`, `fix/`, `chore/`, `hotfix/`, `test/`, in Portuguese kebab-case, starting from `main`.
- On the first implementable plan or goal of a session, create a new branch from `main` unless the user explicitly asks to use the current branch. For continuations of the same plan/goal in the same session, keep the branch already created. If the user says "neste branch", do not switch branches.
- PR CI for `main`: Docker build, RSpec, RuboCop, and Bundler Audit. PRs with red CI must not be merged.
- PRs should be small and focused, with a description of what changed, why, and how to test. Before committing, update/create the local PR `.md` in `docs/` using the GitHub PR template as its standard.
- Review checklist: user scoping, adequate tests, preserved architecture, no unnecessary duplication, no secrets, and no unauthorized dependencies.

## Closeout

- Report tests run, inconclusive commands, and remaining risks objectively, without pasting long outputs.
- Keep the final summary short and prioritize changes made, validation, and real blockers.
