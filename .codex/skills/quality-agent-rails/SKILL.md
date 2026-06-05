---
name: quality-agent-rails
description: Smart Collection Rails quality assurance workflow. Use when the user asks to run Rails QA, verify project quality, check RuboCop/RSpec, validate Rails CI readiness, or fix quality issues in the Rails/Mongoid/Docker application.
---

# Quality Agent Rails

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

6. After Rails code changes, rerun:

```bash
docker compose exec web bundle exec rspec
```

Never finish a Rails QA task with failing tests unless you clearly report the blocker.

## Safety Rules

- Never remove user data segregation. Queries and controller actions must stay scoped through `current_user` whenever user-owned data is involved.
- Never replace scoped access such as `current_user.cars.find(params[:id])` with global access such as `Car.find(params[:id])`.
- Never hardcode secrets, API keys, passwords, or tokens. Use environment variables.
- Do not add gems or libraries without explicit user authorization.
- Preserve the project architecture from `AGENTS.md`: thin controllers, reusable business logic in services, CarrierWave for uploads, Docker Compose for Rails commands.

## Final Report

Report:
- Which Rails QA commands were run.
- How many issues were found, if known.
- Which manual fixes were applied.
- Final RSpec/linter status.

Keep the summary brief and lead with failures if anything remains unresolved.
