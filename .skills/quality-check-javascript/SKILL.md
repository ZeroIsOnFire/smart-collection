---
name: quality-check-javascript
description: Smart Collection JavaScript quality workflow. Use when the user asks to run JavaScript QA, validate esbuild/jsbundling-rails, check npm dependencies, verify Stimulus/Turbo controllers, or when files under app/javascript, package.json, package-lock.json, or JavaScript-related Rails layout/build configuration change.
---

# Quality Check JavaScript

Assume the Smart Collection JavaScript QA role. Keep the esbuild bundle valid, Stimulus controllers registered, dependency locks consistent, and browser-facing text integrated with the Rails i18n pipeline.

## Scope Detection

- For focused JavaScript changes, run the smallest relevant import/build/lint/browser check before the full workflow.
- If `package.json` or `package-lock.json` changed, verify dependencies with npm inside the `web` container.
- If files under `app/javascript/` changed, verify imports, Stimulus registration, and the esbuild bundle.
- If Rails layouts or asset/build configuration changed, verify the generated `application.js` asset is resolvable by Propshaft.
- If the user asks for full JavaScript QA, run the full workflow below.

## Core Workflow

1. Install or verify JavaScript dependencies from the project root:

```bash
docker compose exec web npm ci
```

Use `npm install` only when intentionally updating `package-lock.json`.

2. Build the JavaScript bundle:

```bash
docker compose exec web npm run build
```

3. Verify Rails can resolve the generated bundle:

```bash
docker compose exec web bundle exec rails runner "puts Rails.application.assets.load_path.find('application.js').logical_path"
```

4. Check for dependency vulnerabilities:

```bash
docker compose exec web npm audit
```

5. Run the JavaScript linter:

```bash
docker compose exec web npm run lint
```

Do not add ESLint, Prettier, TypeScript, or other JavaScript tools unless the user explicitly authorizes the new dependency.

## Browser And Playwright Checks

- For visible frontend behavior, first validate the smallest affected route, component, selector, console error, HTTP status, or asset request that can confirm the bug.
- Prefer short temporary checks for assets, fonts, icons, Stimulus registration, Turbo events, or console errors before capturing large HTML or broad screenshots.
- Run focused Playwright specs inside the `web` container when browser behavior changes:

```bash
docker compose exec web npm run test:e2e -- path/to/test.spec.js --browser=chromium
```

- Use `http://127.0.0.1:3000` when the test runs from inside the `web` container.
- Remove or ignore temporary diagnostic artifacts after verification.

## Fixing Issues

- Keep JavaScript dependencies managed by npm and locked in `package-lock.json`.
- Keep generated bundles out of git; only `app/assets/builds/.keep` should be versioned.
- Register new Stimulus controllers in `app/javascript/controllers/index.js`.
- Use relative imports for local modules, such as `../i18n`, instead of importmap aliases.
- Keep JavaScript UI text in `config/locales/javascript.*.yml` and access it through `app/javascript/i18n.js`.
- Preserve Turbo behavior and existing `data-controller` / `data-action` names when refactoring controllers.
- Do not hardcode secrets, API keys, passwords, or tokens in JavaScript.

## Final Report

Report:
- Which JavaScript files or package files were checked.
- Which npm/build/audit commands were run.
- Issues found and fixes applied.
- Final JavaScript QA status, including whether the bundle is Rails-resolvable.
