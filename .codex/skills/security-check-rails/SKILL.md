---
name: security-check-rails
description: Smart Collection security audit workflow. Use when the user asks to run security checks, audit Ruby gems, audit JavaScript or Python dependencies, verify bundler-audit, run OWASP ZAP against the Rails app, investigate vulnerable dependencies, fix security issues, or improve project security posture in this Rails/Mongoid/Python/Docker project.
---

# Security Check Rails

Assume the Smart Collection security role. Audit dependency vulnerabilities across the dependency ecosystems that are present in the repository, run OWASP ZAP against the main Rails application when no equivalent ZAP/OWASP dynamic scan is already covered by the active QA workflow, then fix reported issues conservatively.

## Core Workflow

1. Run Bundler Audit from the project root inside the Rails container:

```bash
docker compose exec web bundle exec bundler-audit check --update
```

2. If JavaScript dependencies are present, audit them:
- Run this only when `package.json` exists with a matching lockfile.
- Use `npm audit` for `package-lock.json`, `pnpm audit` for `pnpm-lock.yaml`, or the appropriate Yarn audit command for `yarn.lock`.
- Do not create a JavaScript manifest or lockfile just to run an audit.

3. If Python dependency files are present, audit them with `pip-audit`:

```bash
docker compose run --rm --entrypoint sh -v .:/workspace upscale-service -c "python -m pip install --no-cache-dir pip-audit && python -m pip_audit -r /workspace/upscale/requirements.txt"
docker compose run --rm --entrypoint sh -v .:/workspace yolo-service -c "python -m pip install --no-cache-dir pip-audit && python -m pip_audit -r /workspace/yolo/requirements.txt"
```

Run the command only for services that exist and have `requirements.txt`.

4. Run OWASP ZAP Baseline only against the main Rails application:
- Before running ZAP, check the active QA/security workflow for an equivalent OWASP ZAP or OWASP dynamic application security scan that already targets the Rails app. If an equivalent scan has already run in this task, record it and skip the duplicate ZAP command.
- Do not run ZAP against the Python microservices.
- Ensure the Rails app is running on the host at `http://localhost:3000`.
- Store generated ZAP reports under `tmp/zap/`, which is ignored by Git.

```bash
docker run --rm -v "${PWD}/tmp/zap:/zap/wrk/:rw" ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t http://host.docker.internal:3000 -r zap-baseline.html -J zap-baseline.json -z "-config replacer.full_list(0).description=rails-host -config replacer.full_list(0).enabled=true -config replacer.full_list(0).matchtype=REQ_HEADER -config replacer.full_list(0).matchstr=Host -config replacer.full_list(0).replacement=localhost:3000"
```

5. Read the full output and identify each advisory:
- vulnerable gem
- vulnerable JavaScript package, when applicable
- vulnerable Python package, when applicable
- OWASP ZAP alert, when applicable
- installed version
- advisory ID / CVE
- patched versions
- affected dependency constraints

6. Fix reported vulnerabilities conservatively:
- Prefer updating only the vulnerable existing dependency and its required transitive dependencies.
- Do not add new gems, npm packages, Python packages, or libraries without explicit user authorization.
- Preserve existing constraints unless the advisory requires a constraint change.
- If a constraint must change, keep the smallest compatible version range that satisfies the advisory and the affected service.
- If an advisory has no patched version available, do not suppress it silently. Report it as residual upstream risk and explain why it could not be fixed.

7. After dependency changes, rerun the relevant security audits and quality agents:

```bash
docker compose exec web bundle exec bundler-audit check --update
docker compose exec web bash bin/qa
```

For JavaScript dependency changes, also rerun the JavaScript audit command from step 2. For Python dependency or Python code changes, also run `$quality-check-python`.

8. If no audit reports vulnerabilities, do not change dependency files.

## Safety Rules

- Never expose secrets, API keys, passwords, tokens, or credential values in logs, commits, or summaries.
- Never remove authentication, authorization, `current_user` scoping, or share-token protections to make tests pass.
- Never run destructive database or Docker volume commands as part of security cleanup.
- Treat security fixes as narrow changes; avoid unrelated refactors.
- Do not commit transient audit/linter tools installed inside containers.

## Final Report

Report:
- The security audit commands that were run.
- Vulnerabilities found, if any.
- Dependency or code changes applied.
- Final security audit, OWASP ZAP, `$quality-check-rails`, and `$quality-check-python` status when applicable.
