# Project Context

## Lifecycle Scripts

This project includes lifecycle scripts in `.martian/config.json`:

- **start-pr** (`.martian/scripts/start-pr.sh`): Run when beginning new work.
  Verifies no uncommitted changes, checks out main, pulls latest from origin.

- **create-pr** (`.martian/scripts/create-pr.sh`): Run when a PR is ready.
  Takes a title as the first argument. Runs ruff lint + format checks, runs
  the full test suite, creates a feature branch, commits, pushes, creates a
  GitHub PR, and squash-merges it. Uses `resolve-venv.sh` to find the correct
  pytest and ruff binaries.

After `create-pr` completes successfully, call `reset_session` with notes
about what was delivered.

## Visual Review with Playwright MCP

This project includes a Playwright MCP server (configured in `.martian/mcp.json`)
that enables visual review of the running application during development.

### When to Use Visual Review

Use the Playwright MCP browser tools to visually verify your work:

- **After completing a page or component** — take a screenshot to confirm
  layout, spacing, and visual hierarchy look correct
- **After CSS changes** — verify responsive behavior at different viewport sizes
- **Before creating a PR** — do a quick visual walkthrough of affected pages
- **When debugging layout issues** — use `browser_snapshot` to inspect the
  accessibility tree and understand what's rendered

### How to Use

1. Make sure the Django dev server is running (`python manage.py runserver`)
2. Use `browser_navigate` to visit `http://localhost:8000/your-page/`
3. Use `browser_snapshot` to inspect the accessibility tree (preferred for
   understanding structure)
4. Use `browser_take_screenshot` to capture visual state
5. Use `browser_resize` to test responsive breakpoints:
   - Mobile: `width=375, height=812`
   - Tablet: `width=768, height=1024`
   - Desktop: `width=1280, height=800`

### Tips

- `browser_snapshot` is better than screenshots for understanding what's on
  the page — it returns the accessibility tree which you can reason about
- Screenshots are useful for verifying visual polish (colors, spacing, images)
- Always check both mobile and desktop layouts for new pages
- After verifying, close the browser with `browser_close` to free resources

## Web Awesome

This project uses Web Awesome Pro for UI components. Key references:

- **Component docs**: `docs/web-awesome.md` — quick reference for components,
  layout utilities, and Playwright testing patterns
- **LLMs context**: `.martian/llms-webawesome.txt` — comprehensive Web Awesome
  documentation for AI context (3000+ lines)

### Key Patterns

- **FOUC prevention**: `<html class="wa-cloak">` + CSS `visibility: hidden`
  until WA kit loads. Never use wa-cloak with a placeholder kit ID.
- **Playwright testing**: Use `PlaywrightE2ETestCase` base class which
  auto-waits for WA hydration. Query wa-* elements with `:has-text()` or
  `.filter(has_text=...)`.
- **Prefer semantic HTML over wa-card**: For text-heavy content, use
  `<article>`, `<section>`, `wa-details`, or plain `div` with CSS accents.
  Reserve `wa-card` for media-rich or interactive content.

## Testing Conventions

- **Test files**: `{view_name}__test.py` (double underscore) in the views directory
- **Two test classes per view**:
  - `Test{Name}(TestCase)` — unit tests (HTTP status, redirects)
  - `Test{Name}Page(PlaywrightE2ETestCase)` — E2E browser tests
- **E2E tests get a `page` parameter** automatically via the base class
- **Parallel execution**: Tests run with pytest-xdist (`-n 8 --dist loadfile`)

## Architecture

- **Views are thin** — parse request, call service, return response
- **Business logic in services** — `services.py` in each app
- **Inside-out development** — start with domain, work outward to adapters
- **HTMX for interactions** — no JSON APIs, server-rendered HTML fragments
