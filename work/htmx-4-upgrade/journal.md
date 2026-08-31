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

## PR 3 — Install Web Awesome agent skills

Grew beyond "adopt npx skills add" into a **cross-tool skills reorg**.
The trigger was noticing that `.agents/skills/` (the open-agent-skills
convention that Vercel-Labs' `skills` CLI writes to) is emerging as the
tool-neutral standard — while our htmx skills from PR #6 lived only at
`.claude/skills/`, Claude-locked. Rather than ship WA in one convention
and htmx in another, we standardized both on `.agents/skills/` as
canonical source of truth, with `.claude/skills/` symlinks pointing at
them for Martian auto-discovery.

### The `.agents/skills/` model (as we finally understood it)

The Vercel-Labs `skills` CLI (`npm i -g skills` — the source behind
`npx skills add`) treats `.agents/skills/` as the shared canonical
location and per-tool dirs (`.claude/skills/`, `.cursor/skills/`,
`.amp/skills/`, ...) as tool-facing indirection. But the CLI *always*
copies rather than symlinks — even without `--copy`. So the
"tool-specific pointer" is a full duplicate, not a lightweight symlink.
That's fine for the CLI's model (each tool gets its own copy it can
customize) but wasteful for a vendored-source template: we'd commit the
same 107 WA files twice, once under `.agents/` and once under `.claude/`.

**Solution:** vendor `.agents/skills/` directly (skip the CLI for the
source-of-truth step), then hand-roll relative symlinks at
`.claude/skills/<name> → ../../.agents/skills/<name>`. Git tracks
symlinks as mode 120000 with the target string as content (~40 bytes
each). Six skills = six symlinks in `.claude/skills/`; the actual
content lives once at `.agents/skills/`.

### Verified: Martian follows symlinks, does NOT auto-load `.agents/skills/`

Two things were empirically verified this PR:

1. **Martian DOES follow symlinks** when scanning `.claude/skills/`. The
   session's available-skills reminder listed all six skills (htmx x4,
   WA x2) after the reorg, even though the actual `SKILL.md` files live
   at `.agents/skills/<name>/SKILL.md`.

2. **Martian does NOT read `.agents/skills/` directly.** A skill
   present only at `.agents/skills/webawesome/SKILL.md` — without the
   `.claude/skills/webawesome` symlink — did not appear in the
   reminder. Confirms the tool-facing dir is required.

That second finding is the load-bearing one for future migrations:
`.agents/skills/` alone isn't discoverable; symlinks (or copies) into
`.claude/skills/` are what make skills visible to Claude Code / Martian.

### Cross-tool downstream workflow

Downstream template users on other AI tools (Cursor, Zed, Amp, Cline,
etc.) generate their tool-specific pointers with:

```
npx skills add ./.agents/skills/<skill-name> -a <agent-name>
```

The `.agents/skills/` tree is the canonical vendored source they
generate from. This is what makes the reorg worth the effort — one
canonical source, N tool-facing views.

### npm setup details

- `package.json` pins `@awesome.me/webawesome@3.12.0` exactly (not
  caret) — reproducibility over silent upgrades.
- `package-lock.json` committed; `node_modules/` gitignored.
- `skills-lock.json` (generated by `npx skills add`) is gitignored —
  it's a byproduct of the CLI's install-tracking, and it's stale
  anyway (only tracks WA, not the htmx skills that got there via
  direct vendoring).
- `npm run skills:sync` is a plain `cp -R` from `node_modules/@awesome.me/webawesome/dist/skills/*` into `.agents/skills/`.
  Existing symlinks in `.claude/skills/` remain valid after sync.
- Upgrade workflow: `npm update @awesome.me/webawesome && npm run skills:sync && git diff`. The diff makes the upgrade *visible* in review — same shape as vendoring but with an npm-pinned version.

### The `-a claude-code` vs `-a claude` gotcha

The `skills` CLI's agent name for Claude Code is `claude-code`, not
`claude`. The first sync attempt used `-a claude` and failed with
`Invalid agents: claude`. Recorded here so the next `npx skills add`
call doesn't repeat the mistake — the full agent list is in
`npx --yes skills --help` output.

### Also carried in this PR

- `.martian/llms-webawesome.txt` deleted (~3000 lines of stale WA 3.3.1
  snapshot, superseded by the `webawesome` skill).
- `martian.md` "Agent Skills" section rewritten to reflect the
  `.agents/skills/` source-of-truth model and document the cross-tool
  `npx skills add` workflow.
- `docs/web-awesome.md` gained a header pointer at the two WA skills,
  framing this file as the project-specific curated subset (things
  the general WA skill can't know: our Playwright base class, our
  `wa-cloak` FOUC setup, the components we use most).
- `plans/htmx-4-upgrade-and-agent-skills-adoption.md` — PR-3 auto-advance
  from the reset after PR #6, bundled here per the "don't leave
  uncommitted state on main" convention.

### Files touched

- `package.json`, `package-lock.json` — new; WA pinned at 3.12.0
- `.gitignore` — `node_modules/`, `skills-lock.json`
- `.claude/skills/*` — 6 relative symlinks (was 4 dirs of htmx `SKILL.md`)
- `.agents/skills/htmx-*/` — 4 skills (moved from `.claude/skills/` via `git mv`, content unchanged)
- `.agents/skills/webawesome/` — new, 99 files
- `.agents/skills/webawesome-design/` — new, 8 files
- `.martian/llms-webawesome.txt` — deleted
- `martian.md` — Agent Skills + Web Awesome sections rewritten
- `docs/web-awesome.md` — header pointer added
- `plans/htmx-4-upgrade-and-agent-skills-adoption.md` — PR-3 advance

## PR 4 — README sweep

Brought the top-level `README.md` up to date with what PRs 1-3 shipped.
The sweep turned out to be entirely additive — a pre-flight grep
confirmed the README had no stale references to
`.martian/llms-webawesome.txt`, pre-htmx-4 event names, or the deleted
extension files. (Lingering matches for those strings all live in this
journal, ADR 001, and the upstream-vendored `htmx-upgrade-from-htmx2`
skill file — correct as historical / upstream artifacts.)

### Structure of the edits

Four surfaces touched, in order of impact:

1. **New `## Agent Skills` section** — the meat of the PR. Placed
   between "Web Awesome Setup" and "Project Structure". Reads top-to-
   bottom: what the six skills are and what each does → where they
   live (`.agents/skills/` canonical, `.claude/skills/` symlinks) →
   cross-tool `npx skills add` workflow → upgrade path
   (`npm update … && npm run skills:sync && git diff`). The
   "canonical source" subsection is the load-bearing part: it tells
   downstream users to edit `.agents/skills/`, not `.claude/skills/`.

2. **Stack list** — bumped htmx to "htmx 4"; added an "Agent skills"
   entry with an anchor link into the new section, so the six skills
   are visible at the top of the README, not buried mid-page.

3. **Project Structure diagram** — added `.agents/skills/` with all
   six skills named individually (readers can see the vocabulary
   without jumping to the new section), `.claude/skills/` called out
   as symlinks, and `package.json` (the new npm-tooling entry point).
   Also picked up `.martian/mcp.json` (Playwright MCP), which the
   diagram had never listed.

4. **Web Awesome Setup pointer** — one line under the kit-URL
   instructions telling readers Claude can help with WA markup on
   demand via the two WA skills.

### The "npm install" question

Considered adding an `npm install` step to Quick Start, but decided
against it. The skills already live in `.agents/skills/` (vendored),
so Claude Code users get them at git-checkout time — no npm needed.
`npm install` is only required if the user wants to (a) run Playwright
MCP or (b) upgrade WA via `npm run skills:sync`. Both are optional
paths, so calling `npm install` out as a required onboarding step
would misrepresent what the template needs. The "Keeping skills
current" subsection is where npm actually shows up, and that's the
right place for it.

### Also carried in this PR

Plan-file advancement (`[x] PR 3 (#7)`, `[-] PR 4`) that was left
uncommitted on `main` after PR #7's `reset_session` — bundled here
per the "never leave uncommitted changes on the primary branch"
convention.

### Note on merge authorization

The user profile forbids interpreting a generic "continue" as merge
authorization. This project's `.martian/scripts/create-pr.sh`
auto-merges (line 188: `gh pr merge --squash --delete-branch`), so
shipping this PR required an explicit `present_options` gate. The
user picked option A (run the script as-is, accept the auto-merge)
— recorded here so future sessions know the pattern: when the
project's create-pr script bundles merge, use `present_options`
rather than assume "continue" covers it.

## What's Next

Plan complete after this PR ships. The htmx-4-upgrade-and-agent-
skills-adoption arc is done: htmx 4 upgrade (PR 1), htmx skills
vendored (PR 2), Web Awesome skills adopted with the cross-tool
`.agents/skills/` reorg (PR 3), README brought current (PR 4).
