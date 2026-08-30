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

## What's Next

**PR 2 — Install htmx 4 agent skills.** Vendor the 4 skill files from
`bigskysoftware/htmx@v4.0.0` at `dist/skills/`:

- `htmx-guidance.md` → `.claude/skills/htmx-guidance/SKILL.md`
- `htmx-debugging.md` → `.claude/skills/htmx-debugging/SKILL.md`
- `htmx-extension-authoring.md` → `.claude/skills/htmx-extension-authoring/SKILL.md`
- `htmx-upgrade-from-htmx2.md` → `.claude/skills/htmx-upgrade-from-htmx2/SKILL.md`

Reference them from `martian.md`. Consider slipping in a small ADR 001
amendment (PR 1 deviations) as tidy-first if the two changes stay
independently reviewable.
