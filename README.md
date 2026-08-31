# Django + Web Awesome + HTMX Template

A project template for building server-rendered web applications with Django, Web Awesome components, and HTMX interactions.

## Stack

- **Django 5.x** — Async-first, server-rendered
- **htmx 4** — Hypermedia-driven interactions (no JSON APIs)
- **Web Awesome** — Web components for consistent UI
- **PostgreSQL** — Primary database
- **Celery + Redis** — Background task processing
- **Playwright** — End-to-end browser testing
- **Agent skills** — Vendored htmx + Web Awesome skills for
  self-updating AI context (see [Agent Skills](#agent-skills))

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

Need help writing Web Awesome markup? Just ask Claude — the `webawesome`
and `webawesome-design` skills (see below) load on demand and cover the
full component API and page-level layout patterns.

## Agent Skills

This template ships with six vendored **agent skills** — self-updating AI
context for htmx 4 and Web Awesome. Skills auto-load in Claude Code out
of the box; other AI tools take one command to wire up.

- **`htmx-guidance`** — writing HTML with htmx (attributes, events, swap
  strategies, common UI patterns).
- **`htmx-debugging`** — diagnosing htmx issues (requests not firing,
  swaps not happening, events not triggering).
- **`htmx-extension-authoring`** — creating, modifying, or debugging
  htmx 4 extensions.
- **`htmx-upgrade-from-htmx2`** — migrating a codebase from htmx 2.x to
  4.x.
- **`webawesome`** — component API reference (buttons, inputs, dialogs,
  layouts, 60+ others).
- **`webawesome-design`** — page-level design (`<wa-page>` layouts,
  theming, brand colors, composition).

### Canonical source: `.agents/skills/`

The six `SKILL.md` files live under `.agents/skills/<name>/SKILL.md` —
the emerging open-agent-skills convention that tool-neutral tooling reads
from. `.claude/skills/` contains six relative symlinks pointing at them,
which is how Claude Code (and Martian) discover the skills. Do not edit
`.claude/skills/` directly; edit or replace `.agents/skills/<name>/`.

### Using the skills in other AI tools

Downstream users on Cursor, Zed, Amp, Cline, or other Claude-Agent-SDK
tools generate their tool-specific pointers with the Vercel-Labs
`skills` CLI:

```bash
npx skills add ./.agents/skills/<skill-name> -a <agent-name>
```

For Claude Code the agent name is `claude-code` (not `claude`), and no
extra step is needed — the symlinks in this repo already work.

### Keeping skills current

- **htmx skills** are vendored from `bigskysoftware/htmx@v4.0.0/dist/skills/`.
  Re-fetch and commit when htmx ships a new minor.
- **Web Awesome skills** are installed via npm and synced into
  `.agents/skills/` by a script:

  ```bash
  npm update @awesome.me/webawesome && npm run skills:sync && git diff
  ```

  The diff makes the upgrade reviewable — same shape as vendoring, but
  with an npm-pinned version.

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
  base.html             # Layout with htmx 4 + Web Awesome
static/
  css/main.css          # Mobile-first responsive CSS
  js/vendor/            # htmx 4 + hx-preload extension (vendored)
.agents/                # Tool-neutral agent skills (canonical source)
  skills/
    htmx-guidance/
    htmx-debugging/
    htmx-extension-authoring/
    htmx-upgrade-from-htmx2/
    webawesome/
    webawesome-design/
.claude/                # Claude Code integration
  skills/               # Six relative symlinks → ../../.agents/skills/*
package.json            # npm dev deps (@awesome.me/webawesome, tooling)
docs/adr/               # Architecture Decision Records
.martian/               # Martian TDD tool configuration
  config.json           # Lifecycle script paths
  mcp.json              # MCP servers (Playwright)
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
