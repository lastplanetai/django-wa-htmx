# htmx 4 upgrade and agent skills adoption

Plan: `plans/htmx-4-upgrade-and-agent-skills-adoption.md`
Governing ADR: `docs/adr/001-htmx-4-upgrade-and-agent-skills.md`

This journal accompanies the multi-PR migration to htmx 4 and the switch
from static AI-context artifacts (`.martian/llms-webawesome.txt`) to the
official agent skills shipped by htmx and Web Awesome.

## Architecture note

htmx is loaded from `static/js/vendor/` (vendored, not from a CDN, per
"reliability" comment in `base.html`). Web Awesome is loaded from a hosted
kit (`kit.webawesome.com/YOUR_KIT_ID.js`) — there is no local WA version
to bump.

Error handling in this template goes through
`myproject/middleware/htmx_errors.py`: 4xx/5xx responses render an
`error_callout.html` fragment for HTMX requests, full error pages
otherwise. This middleware behavior did not change in PR 1 — but its
consumer-facing contract did: htmx 4 swaps 4xx/5xx by default, so any
downstream user wiring an interactive HTMX element must opt into the
error-container target with `hx-status:XXX` per element (see the comment
in `base.html` above `#page-errors`).

## PR 1 — Upgrade htmx to 4.0.0

**Scope grew beyond what the ADR anticipated.** The ADR (§"htmx 4
breaking changes handled") flagged event renames, 4xx/5xx default-swap
behavior, and attribute-inheritance removal — but missed three larger
migrations that a fresh look at the shipped v4.0.0 source surfaced:

1. **`response-targets` extension no longer exists in htmx 4.** The
   ADR said "re-vendor `response-targets` @ 4.x-compatible." That build
   doesn't exist. Response-error targeting is now built into core via
   `hx-status:XXX="target:… swap:…"` attributes. The migration path is
   *not* "swap the extension file" — it's "delete the extension and
   document the per-element `hx-status:4xx` / `hx-status:5xx` pattern."
   The end result is closer to the ADR's Option 3 intent (per-element,
   no inheritance) than the ADR itself described.

2. **`hx-ext="..."` attribute is removed.** In htmx 4, extensions
   activate simply by having their `<script>` tag on the page. So
   `hx-ext="response-targets,preload"` on `<body>` gets deleted
   entirely, not just edited.

3. **`event.detail` structure changed significantly.** htmx 2 exposed
   `event.detail.headers` and `event.detail.xhr`. htmx 4 wraps request
   and response context under `event.detail.ctx`:
   `event.detail.ctx.request.headers`,
   `event.detail.ctx.response.status`. XHR is gone (fetch under the
   hood). This forced a rewrite of the CSRF handler and after-request
   handler in `base.html`, not just event name renames.

Also handled: the `preload="mouseover"` attribute was renamed to
`hx-preload="mouseover"`, and the extension file `htmx-preload.js` is
now `hx-preload.js` (naming convention `hx-*` throughout).

### The scanner is HTML-attribute-focused, not JS-behavior-focused

`npx htmx.org@4.0.0 upgrade-check ./templates` found 4 issues (three
event names + `hx-ext=` removal). It did NOT flag `hx-target-error`,
`hx-swap-error`, `preload=`, or any of the `event.detail.*` JS
references. Anyone relying on the scanner alone would ship a broken
migration — the CSRF handler would silently stop injecting the token,
the after-request status check would compare `undefined >= 200`, and
error responses would be swapped into whatever the default swap target
is instead of `#page-errors`.

**Lesson for future htmx migrations:** run the scanner *and* read the
`htmx-upgrade-from-htmx2.md` skill end-to-end. The scanner catches
mechanical renames; the skill (and the shipped `dist/ext/` directory
listing) catches structural changes.

### The `event.target` decision

htmx 2's `event.detail.elt` gave the source element to global event
listeners. htmx 4's upgrade guide only documents the *extension*
signature (`htmx_before_request(elt, detail)`), not the shape of the
global-listener detail. Rather than probe for `event.detail.ctx.sourceElement`
or `event.detail.elt` (both plausible), the loading-state handlers in
`base.html` use `event.target` — plain DOM event bubbling, guaranteed
to be the element htmx dispatched from. Added optional chaining
(`el?.tagName`) as belt-and-suspenders in case a future event fires on
`document`. If this turns out to be wrong under manual verification,
the fix is one word (`event.detail.ctx.sourceElement`) — but I'd
rather rely on the standard than the framework-specific detail path.

### Follow-up: amend ADR 001

ADR 001 needs a revision to reflect the three deviations above (per
its own "expect one round of docs vs actual behavior" warning). Not
blocking this PR — but the next PR in the plan (PR 2, install htmx
skills) is a natural moment to slip in the ADR amendment as a small
tidy-first if the diff is trivial.

### Files touched

- `static/js/vendor/htmx.min.js` — replaced with 4.0.0 build from unpkg
- `static/js/vendor/hx-preload.js` — added (4.0.0 build); replaces
  `htmx-preload.js`
- `static/js/vendor/htmx-response-targets.js` — deleted (functionality
  now native in core)
- `static/js/vendor/htmx-preload.js` — deleted (renamed)
- `templates/base.html` — event renames, `event.detail.ctx.*` migration,
  body-level attributes dropped, per-element `hx-status:XXX` comment added
- `.gitignore` — `.martian/project_state/` added (transient runtime state)
- `plans/htmx-4-upgrade-and-agent-skills-adoption.md` — plan file
  committed to repo (was previously untracked from `update_plan`)

## PR 2 — Install htmx 4 agent skills

Vendored the 4 htmx 4 skill files from
`bigskysoftware/htmx@v4.0.0/dist/skills/` into `.claude/skills/htmx-*/SKILL.md`:
`htmx-guidance`, `htmx-debugging`, `htmx-extension-authoring`,
`htmx-upgrade-from-htmx2`. Each ships with YAML frontmatter (`name`,
`description`) that Claude Code's SDK reads for progressive-disclosure
loading — descriptions load at session start, full body loads only when
Claude invokes the skill.

### The Martian-auto-load question

The Claude Agent SDK discovers `.claude/skills/*/SKILL.md` automatically
*when the SDK is configured with `setting_sources=["user", "project"]`*
(or defaults, which include both). Martian is a custom harness built on
that SDK — whether it passes those defaults through is not something we
can observe from inside this repo. In this session's available-skills
reminder, only harness/global skills appeared (`loop`, `schedule`,
`claude-api`, `review`, ...); no direct evidence either way.

Rather than probe with a throwaway PR, we chose **belt-and-suspenders**
(Option A on the decision at PR-2 kickoff):

1. Vendor into the standard `.claude/skills/` location — works with
   vanilla Claude Code and matches the ADR's intent.
2. Add an "Agent Skills" section to `martian.md` with one-line pointers
   to each SKILL.md file, so if Martian doesn't auto-load them, the
   descriptions are still surfaced via project instructions and the full
   bodies are one `Read` away.

**Verification hook for PR 3 / PR 4:** in the fresh session after this
PR merges, check the system-reminder's available-skills list. If names
like `htmx-guidance` appear → auto-load works, the `martian.md` pointers
are redundant and can be trimmed in PR 4's README sweep. If they don't →
the pointers are load-bearing and stay.

### ADR 001 amendment slipped in as tidy-first

Also amended `docs/adr/001-htmx-4-upgrade-and-agent-skills.md`:

- Rewrote the PR-plan section to match reality (4 PRs, not 5 — the ADR
  and htmx-4 upgrade shipped together as GitHub PR #5 because the
  upgrade came in below the size guide).
- Added a "Post-implementation notes (PR 1)" section documenting the
  three deviations the journal called out (response-targets deletion,
  `hx-ext=` removal, `event.detail.ctx.*` restructure) plus the
  "scanner alone is not sufficient" lesson.

The amendment is docs-only and independently reviewable — kept in this
PR because both changes close out the "how did PR 1 actually land"
loose ends and the combined diff is still small.

### Files touched

- `.claude/skills/htmx-guidance/SKILL.md` — new (745 lines, vendored)
- `.claude/skills/htmx-debugging/SKILL.md` — new (212 lines, vendored)
- `.claude/skills/htmx-extension-authoring/SKILL.md` — new (372 lines, vendored)
- `.claude/skills/htmx-upgrade-from-htmx2/SKILL.md` — new (364 lines, vendored)
- `martian.md` — added "Agent Skills" section with per-skill pointers
- `docs/adr/001-htmx-4-upgrade-and-agent-skills.md` — PR-plan rewrite +
  post-implementation notes section
- `plans/htmx-4-upgrade-and-agent-skills-adoption.md` — corrected PR-2
  checkbox (was auto-advanced to `[x] (#5)` after PR 1 merged;
  actual state is `[-]` in-flight)

## What's Next

**PR 3 — Install Web Awesome agent skills.** Different installation
story from htmx: WA ships skills as symlink-installable resources
inside the `@awesome.me/webawesome` npm package. Plan per ADR 001:

- Add a minimal `package.json` with `@awesome.me/webawesome` as a dev
  dependency.
- Run `npx skills add ./node_modules/@awesome.me/webawesome/dist/skills/webawesome`
  and the same for `webawesome-design`. These create symlinks under
  `.claude/skills/` so the skills auto-update with each `npm install`.
- Delete `.martian/llms-webawesome.txt` (superseded by the WA skill;
  keeping both invites drift).
- Update `martian.md` — remove the WA-txt reference, add pointers to
  the two WA skills the same way PR 2 did for htmx (only if PR 2's
  auto-load verification comes back negative; otherwise the pointers
  can be simpler).
- Update `docs/web-awesome.md` to reference the skills.

The npm-dependency add is what makes PR 3 non-trivial: the repo doesn't
have a `package.json` today (Node is used only transitively via `npx
@playwright/mcp`). Consider whether the `package.json` should be
committed with a lockfile, or if we should document the install as a
manual step.
