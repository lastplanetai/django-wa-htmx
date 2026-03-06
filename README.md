# Django + Web Awesome + HTMX Template

A project template for building server-rendered web applications with Django, Web Awesome components, and HTMX interactions.

## Stack

- **Django 5.x** — Async-first, server-rendered
- **HTMX** — Hypermedia-driven interactions (no JSON APIs)
- **Web Awesome** — Web components for consistent UI
- **PostgreSQL** — Primary database
- **Celery + Redis** — Background task processing
- **Playwright** — End-to-end browser testing

## Quick Start

1. **Use this template** on GitHub, then clone your new repo

2. **Find and replace** `myproject` with your project name:
   - Rename `myproject/` directory
   - Update all imports in Python files
   - Update `pyproject.toml`, `config/celery.py`, `config/settings/base.py`
   - Update `docker-compose.yml`, `render.yaml`

3. **Install dependencies:**
   ```bash
   poetry install
   ```

4. **Start infrastructure** (PostgreSQL + Redis):
   ```bash
   docker compose up -d
   ```

5. **Create .env** (copy from .env.example and customize):
   ```bash
   cp .env.example .env
   ```

6. **Run migrations:**
   ```bash
   poetry run python manage.py migrate
   ```

7. **Start the dev server:**
   ```bash
   poetry run python manage.py runserver
   ```

8. **Run tests:**
   ```bash
   poetry run pytest
   ```

## Web Awesome Setup

Get your kit URL from [webawesome.com](https://webawesome.com) and replace
`YOUR_KIT_ID` in `templates/base.html`.

## Project Structure

```
config/                  # Django project config
  settings/
    base.py              # Shared settings
    local.py             # Development overrides
    production.py        # Production (Render)
myproject/               # Your app code (rename this)
  apps/
    accounts/            # Custom User model, auth
    www/                 # Public pages (home, health)
  middleware/            # HTMX error handling, cache control
  testing/              # PlaywrightE2ETestCase base class
templates/              # Django templates
  base.html             # Layout with HTMX + Web Awesome
static/
  css/main.css          # Mobile-first responsive CSS
  js/vendor/            # HTMX vendored JS
docs/adr/               # Architecture Decision Records
.martian/               # Martian TDD tool configuration
  config.json           # Lifecycle script paths
  scripts/
    start-pr.sh         # Prepare workspace for new PR
    create-pr.sh        # Lint, test, commit, push, merge PR
```

## Conventions

- **TDD** — Red, green, refactor. Every behavior has a test.
- **Inside-out** — Start with domain logic, work outward to adapters.
- **Small PRs** — One logical change per PR. Merge to main frequently.
- **Services** — Business logic in service functions, not views.
- **Views** — Thin adapters: parse request, call service, return response.

## Deployment

Configured for [Render](https://render.com) via `render.yaml`. Connect your
repo and Render auto-detects the blueprint.

## Martian Integration

This template includes `.martian/` configuration for the
[Martian](https://github.com/lastplanetai/martian) TDD tool:

- **start-pr**: Checks for clean workspace, checkouts main, pulls latest
- **create-pr**: Runs linter, formatter, tests, then creates and merges PR
- **Test command**: Configure via `set_test_command` MCP tool (e.g., `poetry run pytest`)
