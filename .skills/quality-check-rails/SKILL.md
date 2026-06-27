---
name: quality-check-rails
description: Smart Collection Rails quality assurance workflow. Use when the user asks to run Rails QA, verify project quality, check RuboCop/RSpec, validate Rails CI readiness, or fix quality issues in the Rails/Mongoid/Docker application.
---

# Quality Check Rails

Assume the Smart Collection Rails QA role. Keep the Rails application structurally sound, lint-clean, free of avoidable duplication, and green in tests.

## Core Workflow

1. Run the centralized Rails QA script from the project root:

```bash
docker compose exec web bash bin/qa
```

2. Read the full output. The script may continue after linter offenses to show the complete picture.

3. Fix issues that autocorrect does not resolve:
- For RuboCop manual offenses such as `Metrics/MethodLength` or `Metrics/AbcSize`, refactor while preserving behavior.
- Prefer extracting complex controller logic to services in `app/services/`.
- Keep Rails/Mongoid conventions and 2-space Ruby indentation.

4. Address `rails_best_practices` findings carefully:
- Preserve controller/view behavior.
- Do not make broad refactors unrelated to the reported issue.

5. Address `flay` duplication:
- Extract genuinely shared behavior to a service object or concern only when it reduces real duplication.
- Keep security scoping intact.

6. Address `brakeman` findings:
- Treat warnings about authentication, authorization, unsafe redirects, command execution, mass assignment, and secret exposure as high priority.
- Keep all user-owned data access scoped through `current_user`.
- Do not suppress warnings unless the finding is demonstrably false positive and the reason is documented in code or configuration.

7. After Rails code changes, rerun:

```bash
docker compose exec web bin/safe_rspec
```

Never finish a Rails QA task with failing tests unless you clearly report the blocker.

## Docker And Windows Failures

- If `bin/safe_rspec` or `bin/qa` fails with messages like `$'\r': command not found` or `cannot execute: required file not found`, treat CRLF in scripts as the likely cause and use an in-memory workaround without editing the script:

```bash
docker compose exec web sh -lc "tr -d '\r' < bin/safe_rspec | bash -s -- spec/path_spec.rb"
docker compose exec web sh -lc "tr -d '\r' < bin/safe_rspec | bash"
docker compose exec web sh -lc "tr -d '\r' < bin/qa | bash"
```

- If `bin/qa` with CRLF removed in memory fails at the final RSpec step because it calls `bin/safe_rspec` directly, record the partial QA result and run the suite separately with the workaround above.
- If broad QA or a large spec batch times out before useful output, split the run into focused steps: RuboCop for changed files, focused specs, `rails_best_practices`, `flay app/`, and then the full suite when practical.
- If RuboCop reports `Layout/EndOfLine` on changed files in Windows, normalize only those files inside the container and rerun the focused RuboCop check:

```bash
docker compose exec web perl -pi -e 's/\r$//' path/to/file.rb
```

## Safety Rules

- Never remove user data segregation. Queries and controller actions must stay scoped through `current_user` whenever user-owned data is involved.
- Never replace scoped access such as `current_user.cars.find(params[:id])` with global access such as `Car.find(params[:id])`.
- Never hardcode secrets, API keys, passwords, or tokens. Use environment variables.
- Do not add gems or libraries without explicit user authorization.
- Preserve the project architecture from `AGENTS.md`: thin controllers, reusable business logic in `app/services/`, CarrierWave for uploads, Docker Compose for Rails commands.

## Final Report

Report:
- Which Rails QA commands were run.
- How many issues were found, if known.
- Which manual fixes were applied.
- Final RSpec/linter/Brakeman status.

Keep the summary brief and lead with failures if anything remains unresolved.
