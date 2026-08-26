---
name: autopilot
description: Post a saved review to the PR as a GitHub review, then watch for updates and converge — resolving addressed feedback and approving once mergeable
---

# Post the review and drive it to resolution

See `../../CONVENTIONS.md` for the `REVIEW.md` schema, the shared Fibonacci-backoff loop
pattern, and output discipline — this skill uses all three.

Run this after `/review` + `/review:save` have produced `REVIEW.md` / `REVIEW.html` in the worktree root. This command does two things, in order, across a **long-running, self-pacing** session — invoke it as `/loop /review:autopilot` (no interval, so `/loop` self-paces via `ScheduleWakeup`):

1. **Post** the saved findings to the PR as an actual GitHub review (once).
2. **Watch** the PR afterwards: whenever something changes (new commits, comments, reviews), let the quiet period elapse, then do a partial re-review — resolve findings the new commits addressed, and post an approving review once the PR looks mergeable. Keep cycling until the PR is merged or closed.

This is one continuous session — keep a running mental record (not written to disk beyond the artifact updates below) of which findings are open/resolved and what activity you've already processed, so you don't reprocess the same comment twice.

## Establish context (first cycle only)

Read `REVIEW.md` in the worktree root. Parse its frontmatter (`pr`, `title`, `head_sha`, `base`, `reviewed_at`, `verdict`) and its findings (`blocking`, `should-fix`, `nit`, `question`). If it doesn't exist, tell the user to run `/review` and `/review:save` first, and stop.

`<org>/<repo>` and `<N>` come from the frontmatter's `pr: org/repo#N`.

Check whether the review was already posted (in case this session was interrupted and resumed): `gh api repos/<org>/<repo>/pulls/<N>/reviews --jq '.[] | select(.commit_id == "<head_sha>")'`. If a review at that exact `head_sha` already exists, skip straight to the **Watch** phase below.

## Post the review (once, if not already posted)

Turn the findings into a single GitHub review via `gh api repos/<org>/<repo>/pulls/<N>/reviews`:

- **Inline comments** for every finding with a concrete `file:line` — one comment per finding, `path` and `line` (or `start_line`/`line` for a range) from the finding's `where:`, body starting with the severity tag (e.g. `**[should-fix]**`) followed by the concern, in the finding's own words from `REVIEW.md`.
- **Review body** — everything without a clean file anchor: the verdict rationale, "Checked" items (briefly, so the author knows what wasn't re-litigated), and "Open questions". Keep the tone plain and specific, matching `REVIEW.md`'s style rules (no filler, no "great PR overall!").
- **Event**:
  - Any `blocking` findings → `REQUEST_CHANGES`.
  - Only `should-fix`/`nit`/`question`, no `blocking` → `COMMENT`.
  - Never `APPROVE` at this stage, even if `REVIEW.md`'s verdict is `approve` — approval is reserved for the convergence check below, after the author has had a chance to respond.

Submit with `gh api --method POST repos/<org>/<repo>/pulls/<N>/reviews -f commit_id=<head_sha> -f event=<EVENT> -f body=<BODY> -f 'comments[]=...'` (build the JSON payload properly — use a temp file with `gh api --input -` if the comment set is large or contains special characters, rather than fighting shell quoting).

Record in `REVIEW.md` (and mirror in `REVIEW.html`) that the review was posted: append a `## Autopilot log` section with a timestamped entry ("posted review as `REQUEST_CHANGES`/`COMMENT`, N inline comments").

## Watch phase: debounced convergence loop

Each cycle, gather (read-only, batched):

1. **Current PR head + state** — `gh pr view <N> --json headRefOid,state,mergeable,reviewDecision -q .`.
2. **Commits since last processed head** — `git fetch` the PR ref, then `git log --oneline <last_head>..<new_head>` and `git diff --stat` (same reachability caveat as `/review:refresh` — if force-pushed, note it and use `gh pr view --json commits` instead).
3. **New reviews / comments since last processed timestamp** — same three `gh api` calls as `/review:refresh` (`pulls/<N>/reviews`, `pulls/<N>/comments`, `issues/<N>/comments`), filtered by `created_at`/`submitted_at` greater than the last timestamp you processed.

Compute the latest activity timestamp across all of the above (`new_head`'s push time, or the newest comment/review timestamp).

### Debounce via the backoff counter itself

Use the shared Fibonacci backoff counter from `../../CONVENTIONS.md`. Also track a
`pending` flag: whether there's unprocessed activity waiting out its quiet period.

- **New activity found this cycle** (a commit, comment, or review not seen before) → set `pending = true`, **reset the counter to `1`**. Don't act yet — a burst of pushes/comments should land as one batch, not trigger a re-review per event. Skip to "Decide the next wakeup".
- **No new activity this cycle, and `pending` is false** → genuinely idle. Advance the counter to the next Fibonacci step. Skip to "Decide the next wakeup".
- **No new activity this cycle, `pending` is true** → advance the counter to the next Fibonacci step *first*, then check the advanced value: if it's now `>= 3`, the quiet period has held for enough backoff steps — clear `pending` and proceed to the re-review below in this same cycle (don't wait for another cycle to notice). Otherwise keep `pending = true` and skip to "Decide the next wakeup" to wait longer. (Checking the pre-advance value here is the classic off-by-one: it delays the re-review by one whole extra backoff step past when the threshold was actually reached.)

### Partial re-review

For each currently-open finding (from `REVIEW.md`, plus anything raised by other reviewers since):

1. Read the current code at the relevant path/lines.
2. Classify: **addressed** (a commit since the finding was raised clearly resolves it), **not-addressed**, or **borderline** (partially done, or addressed only by discussion).
3. **Addressed** → reply on the review thread confirming resolution, then resolve the GitHub conversation thread via GraphQL (`gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<id>"}) { thread { isResolved } } }'` — fetch `threadId` via the `reviewThreads` GraphQL query if you don't have it from REST). Move the finding to "Resolved" in `REVIEW.md` (mirroring `/review:refresh`'s update-in-place style), don't delete it.
4. **Not-addressed / borderline** → leave the thread open, no action needed unless the author asked a direct question — answer it if so.

Also fold in any *new* reviewer feedback from this window the same way `/review:watch`'s reviewer-facing counterpart would: if a human reviewer raised something new, treat it as a new open finding (add it to `REVIEW.md`) rather than silently dropping it.

### Decide mergeability

Once the addressed/not-addressed pass is done, check whether the PR now looks mergeable:

- No `blocking` findings remain open.
- No unresolved `CHANGES_REQUESTED` review from a human reviewer stands unaddressed.
- No new merge risk introduced by the commits since the last check (same lens as `/review:gate`'s Area 2 — backward-incompatible API/config/behavioral changes).

If mergeable and you haven't already posted an approval for this exact head SHA: submit `gh api --method POST repos/<org>/<repo>/pulls/<N>/reviews -f commit_id=<new_head> -f event=APPROVE -f body=<brief note: what was resolved since the last review, why this now looks good>`.

If not yet mergeable, don't approve — just leave the summary of what's still open for the next cycle.

Update `REVIEW.md` / `REVIEW.html` after each substantive cycle (findings moved to Resolved, new findings added, `## Autopilot log` entry appended with what happened: SHA range covered, findings resolved, approval posted or not and why). Keep both files in sync, same discipline as `/review:refresh`.

## Decide the next wakeup: fibonacci backoff

- **PR merged or closed** → print closing summary, `stop: true`, regardless of the counter.
- **You just acted this cycle** (posted the initial review, resolved a finding, folded in new feedback, or posted an approval) → **reset the counter to `1`** — you want to see the fallout (a reply, new push, CI reaction) soon. Clear `pending`.
- **Otherwise** → the counter was already updated per the debounce rules above (reset to `1` on new activity, advanced on idle/quiet-out cycles). Use it as-is.

Call `ScheduleWakeup` with `delaySeconds` = counter minutes × 60, `prompt` set to the same `/loop` invocation text (typically `/review:autopilot`), and a one-sentence `reason` (e.g. "new commit pushed, waiting out quiet period" / "no activity, backing off to 8 min" / "just approved, watching for merge").

## Output discipline

Gather, analyze, resolve threads, and edit artifacts **first**, silently (shared
output-discipline pattern). Then print **one** summary as the last thing before scheduling
the wakeup:

- What triggered this cycle (or "no new activity" for idle cycles).
- Findings resolved this cycle (one line each, with the commit that addressed it).
- Findings still open (one line each).
- New feedback folded in, if any.
- Mergeability verdict and whether an approval was posted.
- The current backoff counter and the next wakeup interval.

No emoji, no filler. Be specific: SHAs, file:line, reviewer names, timestamps.
