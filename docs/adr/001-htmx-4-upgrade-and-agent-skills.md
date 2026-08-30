# ADR 001: Upgrade to htmx 4 and adopt agent skills for AI context

## Status

Accepted

## Context

Two things are stale in this template:

1. **htmx is on 1.x/2.x-era vendored files.** `static/js/vendor/htmx.min.js`
   and the two extensions (`htmx-response-targets.js`, `htmx-preload.js`)
   predate htmx 4.0.0 (released 2026-08-28). `templates/base.html` uses
   pre-4 event names (`htmx:configRequest`, `htmx:beforeRequest`,
   `htmx:afterRequest`) and leans on implicit attribute inheritance
   (body-level `hx-target-error`, `hx-swap-error`, `preload="mouseover"`)
   that htmx 4 no longer honors by default.

2. **AI context for both libraries is stale and static.** `.martian/llms-webawesome.txt`
   is a 3000-line snapshot of Web Awesome 3.3.1 that has to be manually
   refreshed. htmx has no dedicated AI-context file at all. Meanwhile, both
   projects have shipped official Claude/Cursor-compatible **agent skills**
   that stay current with releases:
   - htmx: 4 skill files at `github.com/bigskysoftware/htmx/tree/v4.0.0/dist/skills/`
     (guidance, debugging, extension-authoring, upgrade-from-htmx2).
   - Web Awesome: two skills (`webawesome`, `webawesome-design`) shipped
     inside `node_modules/@awesome.me/webawesome/dist/skills/`, installed
     via `npx skills add` as symlinks so they update with the WA package.

Web Awesome itself is loaded from a hosted kit (`kit.webawesome.com/YOUR_KIT_ID.js`),
so there's no local WA version to bump — the "WA upgrade" reduces to
adopting the agent skills and dropping the stale text snapshot.

## Decision

Upgrade htmx to 4.0.0, migrate the template to the idiomatic htmx 4
attribute pattern (per-element, no implicit inheritance), and replace the
static AI-context artifacts with the official agent skills from both
projects.

### htmx 4 migration approach — per-element error targeting

Three viable strategies for the body-level `hx-target-error` /
`hx-swap-error` / `preload` attributes:

1. Set `htmx.config.implicitInheritance = true` — one-line compat shim.
2. Add `:inherited` suffix to each body-level attribute — explicit, still
   inheritance-based.
3. **Remove body-level defaults entirely; put targeting on each interactive
   element.** No inheritance, most idiomatic htmx 4.

We chose Option 3. Reasoning:

- This template ships with **zero interactive HTMX in content templates**
  today — `home.html` has no `hx-get`/`hx-post`. The body-level attributes
  are speculative defaults with no consumers, so removing them costs
  nothing and doesn't force a follow-up sweep.
- Downstream users adding interactive HTMX will think about error handling
  *at the point of the interaction*, which is where the decision actually
  belongs. A body-level default hides that decision.
- We keep `<div id="page-errors">` as a convention and add a comment in
  `base.html` showing the per-element pattern
  (`hx-target-error="#page-errors" hx-swap-error="innerHTML"`) so the
  pattern is discoverable without being magic.

Trade-off accepted: downstream users get slightly more boilerplate per
interactive element. Worth it for the explicitness and for staying aligned
with htmx 4's design.

### Agent skills — vendor htmx, npm-install Web Awesome

Different installation stories for different reasons:

- **htmx skills**: 4 static markdown files. Vendor them under
  `.claude/skills/htmx-*/SKILL.md`, checked into the repo. Zero setup for
  anyone cloning the template; upgrade path is "re-download when htmx
  ships a new minor."
- **Web Awesome skills**: shipped as symlink-installable resources inside
  the npm package. Adopt `npx skills add`. This introduces a `package.json`
  with `@awesome.me/webawesome` as a dev dependency, but the payoff is
  that the skills auto-update with each `npm install`. The repo already
  implicitly needs Node (`npx @playwright/mcp` in `.martian/mcp.json`), so
  we're not adding a new runtime requirement.

Delete `.martian/llms-webawesome.txt` — the WA skill supersedes it, and
keeping both invites drift.

### htmx 4 breaking changes handled

- **Event renaming**: `htmx:configRequest` → `htmx:config:request`,
  `htmx:beforeRequest` → `htmx:before:request`, `htmx:afterRequest` →
  `htmx:after:request`. All three appear in the `<script>` block in
  `base.html`; rename in place.
- **400/500 trigger swaps by default**: aligns with our existing
  `htmx_error_middleware` behavior — net win, no code change needed, but
  verify end-to-end during PR 2.
- **Attribute inheritance removed**: handled by Option 3 above.
- **`hx-partial`, morph swaps, `hx-history-cache`**: new features, not
  needed for this template.

## PR Plan

The plan settled at four PRs, one smaller than the original five: PR 1
(this ADR) and the htmx-4 upgrade shipped together as GitHub PR #5
because the upgrade came in below the PR-size guide, and the ADR is
what made the upgrade reviewable in the first place.

1. **ADR + htmx 4 upgrade** (shipped as #5).
2. **Install htmx 4 agent skills.** Vendor the 4 skill files under
   `.claude/skills/htmx-guidance/SKILL.md`,
   `.claude/skills/htmx-debugging/SKILL.md`,
   `.claude/skills/htmx-extension-authoring/SKILL.md`,
   `.claude/skills/htmx-upgrade-from-htmx2/SKILL.md`. Reference them
   from `martian.md`.
3. **Install Web Awesome agent skills.** Add a minimal `package.json`
   with `@awesome.me/webawesome` as a dev dependency plus the
   documented `npx skills add` one-liner. Delete
   `.martian/llms-webawesome.txt`. Update `martian.md` and
   `docs/web-awesome.md` to reference the skills.
4. **README sweep.** Add a "Skills" section to the README; scrub any
   remaining references to old htmx events or the deleted WA snapshot.

## Post-implementation notes (PR 1)

The ADR warned that htmx 4 was two days old and one round of "docs said
X, behavior was Y" was likely. That round happened. Three deviations
worth recording:

1. **`response-targets` as an extension no longer exists in htmx 4.**
   The ADR said "re-vendor `response-targets` @ 4.x-compatible." That
   build doesn't exist — the functionality moved into core as per-element
   `hx-status:XXX="target:… swap:…"` attributes. The migration was
   *delete the extension file and document the per-element pattern in
   `base.html`*, not swap a version. End result actually lands closer
   to this ADR's Option 3 intent (per-element, no inheritance) than the
   ADR anticipated.

2. **`hx-ext="..."` attribute is removed in htmx 4.** Extensions now
   auto-activate from their `<script>` tag alone, so
   `hx-ext="response-targets,preload"` on `<body>` was deleted outright
   rather than edited.

3. **`event.detail` structure changed significantly.** htmx 2 exposed
   `event.detail.headers` and `event.detail.xhr`. htmx 4 wraps them
   under `event.detail.ctx` (`ctx.request.headers`, `ctx.response.status`)
   and drops XHR entirely (fetch under the hood). The CSRF handler and
   after-request handler in `base.html` needed structural rewrites, not
   just event-name renames.

**Lesson for future htmx migrations:** `npx htmx.org@4.0.0 upgrade-check`
is HTML-attribute-focused and caught only the three event renames plus
`hx-ext=`. It did NOT flag `hx-target-error`, `hx-swap-error`,
`preload=`, or any of the `event.detail.*` JS references. Run the
scanner *and* read `htmx-upgrade-from-htmx2.md` end-to-end — the
scanner catches mechanical renames, the skill catches structural
changes. PR 2 makes that skill discoverable in this repo.

Additional smaller fact: extension filenames changed from `htmx-*.js` to
`hx-*.js` (e.g. `htmx-preload.js` → `hx-preload.js`), and the
`preload="mouseover"` attribute is now `hx-preload="mouseover"`.

## Consequences

**Easier:**

- Downstream users get current, self-updating AI context for both htmx
  and Web Awesome. No more "the LLM is telling me about WA 3.3.1 APIs
  that no longer exist."
- Migrations to future htmx versions get simpler because we've already
  moved off implicit inheritance — the next breaking change touches
  fewer surfaces.
- Error targeting decisions live at the point of interaction, which is
  where new engineers naturally look for them.

**Harder:**

- Interactive HTMX elements need explicit `hx-target-error` /
  `hx-swap-error` per element. Slightly more boilerplate than a global
  default.
- The template now has a `package.json` alongside `pyproject.toml`. Adds
  one dev dependency and one install step to onboarding.
- htmx 4.0.0 is 2 days old at the time of this ADR. Expect one round of
  "the docs said X, the actual behavior is Y" during PR 2 — especially
  around the `response-targets` and `preload` extensions, whose 4.x
  status wasn't fully confirmed by the release announcement.
