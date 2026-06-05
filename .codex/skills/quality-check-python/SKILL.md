---
name: quality-check-python
description: Smart Collection Python microservice quality workflow. Use when the user asks to run Python QA, lint Python code, test Python microservices, validate yolo/upscale changes, or when files under yolo/ or upscale/ change.
---

# Quality Check Python

Assume the Smart Collection Python QA role. Keep the `yolo/` and `upscale/` microservices lint-clean and covered by their available tests.

## Scope Detection

- If Python files under `upscale/` changed, read `upscale/AGENTS.md` and run the upscale checks.
- If Python files under `yolo/` changed, read `yolo/AGENTS.md` and run the YOLO checks.
- If the user asks for full Python QA, run checks for both services.

## Linters

Run Ruff as the default Python linter. Ruff is a transient QA tool here; do not add it to project requirements unless the user explicitly asks.

Preferred Docker Compose commands, validating the current workspace files:

```bash
docker compose run --rm --entrypoint sh -v .:/workspace upscale-service -c "python -m pip install --no-cache-dir ruff && python -m ruff check --ignore E402 /workspace/upscale/main.py /workspace/upscale/test_main.py"
docker compose run --rm --entrypoint sh -v .:/workspace yolo-service -c "python -m pip install --no-cache-dir ruff && python -m ruff check --ignore E402 /workspace/yolo/main.py"
```

Ignore `E402` because both Python services intentionally monkeypatch runtime libraries before importing heavy ML dependencies.

If a service container is unavailable, use an equivalent ephemeral Docker Compose run or clearly report the blocker.

## Tests

For `upscale/`, run the unit tests:

```bash
docker compose run --rm --entrypoint python --workdir /workspace -v .:/workspace upscale-service -m unittest upscale/test_main.py
```

For `yolo/`, run available tests if present. If there are no test files, run lint plus a syntax check and report that no YOLO test suite exists yet:

```bash
docker compose run --rm --entrypoint python -v .:/workspace yolo-service -m py_compile /workspace/yolo/main.py
```

## Fixing Issues

- Preserve the monkeypatches and offline-mode rules documented in the service `AGENTS.md` files.
- Do not add Python dependencies to `requirements.txt` without explicit user authorization.
- Do not download models or require GPU access for unit tests.
- Keep changes narrow to the failing linter/test issue.

## Final Report

Report:
- Which Python services were checked.
- Which lint/test commands were run.
- Issues found and fixes applied.
- Final Python QA status, including any missing test suite.
