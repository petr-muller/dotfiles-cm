# `review:*` shared conventions

Read by whichever `review:*` skill is running when its own `SKILL.md` points here.
This file holds the conventions repeated across skills; each skill's `SKILL.md`
covers only what's specific to it.

## How the skills chain together

```
/review                (built-in review skill; not part of this plugin)
   │
   ▼
/review:save            → writes REVIEW.md + REVIEW.html
   │
   ├─→ /review:refresh          → updates artifacts as the PR evolves, or flags for re-review
   ├─→ /review:gate             → mergeability call: findings addressed? + independent risk pass
   ├─→ /review:address          → walk PR feedback on MY authored PR, one item at a time
   ├─→ /review:autopilot        → post REVIEW.md as a GitHub review, then watch to convergence
   └─→ /review:followup         → post-merge: mine for followup work, record into REVIEW.md
          │
          └─→ /review:followup-address   → fresh worktree, execute recorded handoff prompts
                                              (both `## Followups` and `## Dependency followups`)

/review:watch            → long-running loop watching MY OWN authored PR (CI + feedback), independent of REVIEW.md
/review:depbump          → dependency-bump review (safety/freshness/exposure); optionally
                              invokes /code-review for any accompanying code changes
/review:depbump-followup → mines the dep bump's changelog for followup work, same recording
                              mechanism as /review:followup (separate "Dependency followups"
                              section) — also consumed by /review:followup-address
```

`save` produces the artifact; everything else either reads it, updates it, or (in `watch`'s
case) operates independently of it because it's about *my* PR, not one I'm reviewing.

## Establishing PR/repo context from a worktree

Skills that operate on a PR being reviewed (`refresh`, `gate`, `address`, `autopilot`,
`followup`, `depbump`, `depbump-followup`) resolve context the same way:

- **PR number** — the worktree's branch name is typically `N-review` or `N-summarize`;
  extract `N`. If that doesn't match, infer the PR from the checked-out branch via
  `gh pr view`.
- **`<org>/<repo>`** — from the git remotes: prefer `upstream`, fall back to `origin`.
- If the worktree doesn't correspond to a PR, say so and stop.

Every `gh api` call that lists reviews, comments, or timeline events must pass
`--paginate` — the API returns 30 items per page, so without it busy PRs silently lose
their older activity.

`watch` differs: it runs on a branch *I* authored (a `work::claude` session), so it looks
the PR up by head branch (`gh pr list --head <branch>`) instead of a `N-review` pattern.

`followup-address` differs again: its input is a bare PR number (argument or inferred),
and it fetches `REVIEW.md` from the published `<N>-review` branch (the reviewer account's fork
for public repos, `origin` for private ones) rather than reading a local worktree file — see
that skill for specifics.

## `REVIEW.md` / `REVIEW.html` artifact schema

Defined authoritatively by `/review:save`; every other skill that reads or writes these
files follows this schema.

**`REVIEW.md` is the single source of truth; `REVIEW.html` is generated from it.** Never
hand-write or hand-edit the HTML. Any skill that writes or changes `REVIEW.md` finishes by
regenerating the HTML, from the worktree root:

```
python3 <skill-base-dir>/../../scripts/render.py REVIEW.md    # writes REVIEW.html next to it
```

(`<skill-base-dir>` is the running skill's base directory, given when the skill loads.)

The renderer builds the header (PR link, SHAs, verdict and gate badges) from the
frontmatter and renders the body as-is, coloring `### [tag]` finding chips — so everything a
human should see must be in the MD body. Use plain Markdown (headings, `-`/`1.` lists,
fenced code, `- key: |` literal blocks, inline code/bold/links); no raw HTML.

**Body section order** (skills that add sections insert them where noted):

```
# Review
## Gate                 (added by /review:gate)
## Verdict              one line + one-paragraph rationale
## What this PR does    3-5 bullets, my words; "Since previous review" bullets appended by refresh
## Re-review recommended (added by /review:refresh)
## Findings             ordered blocking → should-fix → nit → question
## Resolved
## Checked
## Open questions
## Autopilot log / ## Followups / ## Dependency followups   (appended by those skills)
```

**YAML frontmatter**:

```yaml
---
pr: org/repo#N
title: "..."
head_sha: <full-sha>
base: main
reviewed_at: 2026-05-13T17:49:00Z
verdict: approve | request-changes | needs-discussion
---
```

- `reviewed_at` must be UTC with a literal `Z` suffix (`date -u -Iseconds | sed 's/+00:00/Z/'`)
  — matches GitHub's timestamp format exactly so timestamps compare lexicographically against
  `created_at`/`submitted_at` from the GitHub API.
- Skills that update the artifact in place (`refresh`, `autopilot`) bump `head_sha` and
  `reviewed_at` and may append their own log lists to the frontmatter (`refresh_log:`,
  `recommended_rereview:`) — see those skills for the exact shape.

**Findings** — flat list, one entry per finding, exactly these severity tokens:
`blocking`, `should-fix`, `nit`, `question`.

```markdown
## Findings

### [blocking] short title
- where: `file/path.go:42-58`
- concern: one or two sentences.
- excerpt: |
    actual code lines
```

Findings that get resolved later move to a **Resolved** section rather than being deleted
— they're useful history for anyone reading the artifact afterward.

**Other standard sections**: `## Checked` (short list, so nothing gets re-investigated),
`## Open questions`. Skills that append their own record of activity use their own headings
(`## Autopilot log`, `## Followups`, `## Dependency followups`) — additive, never touching
frontmatter or existing findings.

**Style rules**: be specific (`file:line`, quote real code, not paraphrase);
say so explicitly when uncertain; don't repeat the diff verbatim, point at where to focus;
no emoji, no filler, no "great PR overall!".

## Followup handoff prompts

`followup` and `depbump-followup` both produce **self-contained prompts** for a cold agent
to execute later (by `followup-address` or by hand). Each prompt must stand alone — the
executing agent has no memory of this session:

- **What and where** — repo, which PR/bump enabled this, specific files/call sites.
- **The task** — an imperative instruction, not a description of one.
- **Acceptance criteria** — how the agent knows it's done.
- **Scope guard** — what's explicitly out of scope, so it doesn't sprawl.

Both skills record accepted followups into `REVIEW.md` (when it exists) under their own
section, then re-render the HTML — never fabricate the file if absent.

## Opportunity walk-and-record loop (`followup`, `depbump-followup`)

Both skills mine a different source for post-merge opportunities (review threads/TODOs/the
neighbourhood vs. a dependency's changelog×usage) but present and record them identically.
Each skill's own `SKILL.md` covers only its opportunity-sourcing step and its question-text
template; the mechanics below are shared.

**Candidate shape**: title, category (a short label — coin one if none of the skill's
suggested labels fits), where (`file:line`/area/call-sites), necessity (`must` / `should` /
`could`, honestly — don't inflate a `could` into a `must`), plus whatever the skill adds
(e.g. depbump-followup's module+version). Read the actual code/call sites before forming an
opinion on each — never echo the source blind. Never drop a candidate for being a
blocker or an unresolved review finding: once the PR is merged (or about to be), findings
that were not addressed before merge are exactly the most urgent followups — include them,
mark them `must` or `should`, and say what was left unfixed. Only when the PR is still
open and unmerged *and* the item is a genuine merge blocker, flag it as such (and mention
`/review:gate`) in addition to listing it — don't silently omit it.

**Walk one at a time** — never batch. `AskUserQuestion` per candidate with three options,
putting the draft handoff prompt (or the proposed scope, for long ones) in the **Accept**
option's `preview` field so it can be read side by side with the decision:
- **Accept** — collect it as a to-be-written handoff prompt (see `../../CONVENTIONS.md`'s
  handoff-prompt format), then move straight to the next item.
- **Skip** — drop it, move straight to the next item.
- **Discuss** — free-form conversation to refine or challenge, then **re-present the same
  item** with `AskUserQuestion`, scope revised per the discussion.

Never ask "continue?" between items.

**After all items**:
1. One-line tally: accepted vs. skipped.
2. Each accepted item's handoff prompt in its own fenced code block, titled with the
   item — trivially copy-pasteable to dispatch to a separate agent.
3. **Whenever `REVIEW.md` exists**, append (or replace, on re-runs) the skill's named section
   (`## Followups` / `## Dependency followups`) recording every accepted item — not
   optional, written every run the file is present. Never touch frontmatter or existing
   findings; never create `REVIEW.md` if it's absent.
4. If step 3 wrote `REVIEW.md`, regenerate `REVIEW.html` with `render.py` (see the artifact
   schema above). Each handoff prompt goes in a fenced code block so it renders as `<pre>`.

Never commit, and never start doing the work itself — identify and hand off only.

## Long-running loops (`watch`, `autopilot`)

Both are invoked via `/loop` with no interval (self-pacing through `ScheduleWakeup`), and
share a **Fibonacci backoff** in minutes: `1, 1, 2, 3, 5, 8, 13, 21, 34`, capped at `34`.

- New activity (a commit, comment, review — from anyone, or an action you just took) →
  reset the counter to `1`.
- Nothing happened this cycle → advance to the next step.
- PR merged/closed → `stop: true`, unconditionally.

Each loop fires `ScheduleWakeup` with `noop: true` on cycles where nothing happened (no new
activity, no action taken) and `noop: false` otherwise, so idle stretches collapse in the
terminal instead of scrolling.

### Loop state lives on disk

These loops run for hours or days, and the conversation will be summarized along the way —
anything kept only "in mind" can be lost, which leads to double replies or re-processed
comments. So the loop's bookkeeping lives in a JSON file inside the worktree's git dir
(never committed, never pushed, per-worktree):

```
STATE=$(git rev-parse --git-path review-loop-<skill>.json)   # <skill> = watch | autopilot
```

Shape (add fields a skill needs; keep it small):

```json
{
  "pr": "org/repo#N",
  "last_head": "<sha>",
  "last_activity_at": "<ISO 8601 UTC, Z>",
  "counter": 1,
  "pending": false,
  "handled": {
    "comments": {"<id>": "addressed|pushed-back|deferred|answered|skipped"},
    "reviews": {"<id>": "..."},
    "checks": {"<name>@<sha>": "fixed|flake|pending"}
  },
  "posted": {"review_at_sha": "<sha or null>", "approval_at_sha": "<sha or null>"}
}
```

- **Read it at the start of every cycle**; if absent, this is the first cycle — create it.
- **Write it at the end of every cycle**, after acting and before `ScheduleWakeup`.
- An item is new if its id isn't in `handled`, or it changed since (a new reply in the
  thread, a new push touching it) — then re-examine it and overwrite its entry.
- Before any outward action (reply, resolve, post review, approve), also check GitHub itself
  where cheap (e.g. "is my reply already in this thread?") — the state file can lag if a
  cycle crashed mid-way, so it's idempotency help, not the source of truth.
- Loop ends (PR merged/closed) → delete the file.

### Debounced convergence (`autopilot` only)

`autopilot` layers a `pending` flag on top of the plain backoff counter above, so a burst of
activity settles before it triggers a partial re-review. Each cycle, exactly one of these
three branches fires — check them in this order:

1. **New activity found this cycle** (a commit, comment, or review not seen before) → set
   `pending = true`, reset the counter to `1`. Do not act yet. Go to "decide next wakeup".
2. **No new activity, `pending` is `false`** → genuinely idle. Advance the counter to the
   next Fibonacci step. Go to "decide next wakeup".
3. **No new activity, `pending` is `true`** → **advance the counter first**, then compare
   the *post-advance* value: if `>= 3`, the quiet period has held long enough — clear
   `pending` and run the partial re-review in this same cycle. Otherwise leave `pending =
   true` and go to "decide next wakeup" to wait longer.

Branch 3 must compare the counter **after** advancing it, not before — comparing the
pre-advance value is an off-by-one that delays convergence by one whole extra backoff step
past the moment the threshold was actually reached.

## Output discipline

Every tool call is visible to the user, so mechanical back-and-forth narration
("now fetching...", "now updating...") just adds noise. The pattern used by `refresh`,
`watch`, `autopilot`, and `depbump`:

1. **Gather + act, silently.** All data gathering, file edits, replies, and commits happen
   first, with no narrative text between tool calls.
2. **One summary, last.** A single self-contained block after everything is done — specific
   (names, SHAs, `file:line`, timestamps), no emoji, no filler.
