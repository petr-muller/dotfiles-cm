---
name: followup-address
description: Address the followups recorded by /review:followup and /review:depbump-followup for a PR — fetch its REVIEW.md, read the Followups and Dependency followups sections, and carry out each handoff prompt in this fresh worktree
argument-hint: [PR-number]
disable-model-invocation: true
---

# Address recorded followups

See `../../CONVENTIONS.md` for the handoff-prompt format and how the `review:*` skills chain.

`/review:followup` and `/review:depbump-followup` each walk a PR's post-merge opportunities and record the accepted ones — title, category, necessity, where, and a **self-contained handoff prompt** — into `## Followups` and `## Dependency followups` sections of that PR's `REVIEW.md`, respectively. This command is the other half of both: run in a **freshly started worktree/branch** (on the merged default branch / current `main`, which is exactly the cold-agent context those prompts were written for) and **do the work** those prompts describe.

The input is a **PR number**. The followups were already vetted by the user when `/review:followup`/`/review:depbump-followup` ran, so this command doesn't re-judge them — it executes them.

## Establish context

1. **PR number** — take it from the command argument (`$ARGUMENTS`). If none was given, try to infer `N` from the checked-out branch name (e.g. a leading number, or a `N-followup`-style prefix). If you can't determine a PR number, say so and stop.
2. **`<org>/<repo>`** — from the git remotes (prefer `upstream`, fall back to `origin`). Where the REVIEW.md branch lives depends on the repo's visibility (see below).

## Fetch the PR's REVIEW.md

`pr::review::push` publishes each review worktree as the branch `N-review`, with `REVIEW.md` committed at its root — but **where** depends on the repo's visibility (mirroring `pr::_push_review_artifacts` / `pr::_replay_artifacts`):

- **Public repo** → the reviewer account's fork, `petr-muller-reviewer/<repo>`. This is the normal case.
- **Private repo** (or visibility can't be determined) → `origin` (my own fork).

That branch is the source of truth here — **do not** go hunting through sibling worktrees or the canonical working copy, and don't fall back from one location to the other (a stale `N-review` on `origin` may predate the reviewer-fork switch).

```
if [ "$(gh api repos/<org>/<repo> --jq .private)" = false ]; then
  git fetch https://github.com/petr-muller-reviewer/<repo>.git <N>-review   # anonymous HTTPS read is enough
else
  git fetch origin <N>-review
fi
git show FETCH_HEAD:REVIEW.md
```

- If the fetch fails, there's no published review for this PR at that location — say so (naming the location you checked) and stop.
- If `REVIEW.md` isn't present on that branch, or it has **neither a `## Followups` nor a `## Dependency followups` section** (or both are empty, or hold only a note that no opportunities were identified), there are no recorded followups to address — say so and stop. This command never re-derives followups; that's `/review:followup`'s and `/review:depbump-followup`'s job.

Read the whole `REVIEW.md` for context (the findings and frontmatter explain *why* each followup exists), but the **`## Followups` and `## Dependency followups` sections are what you act on** — read whichever are present; either may be absent.

## Parse the followups

From each present section (`## Followups`, `## Dependency followups`), extract every recorded followup: its title, category, necessity (must / should / could), mode (`deliver`, or `probe` — treat a missing mode as `deliver`), where (`file:line`, area, or affected call sites), and — the operative part — its **handoff prompt** (the fenced code block). Each handoff prompt is written to stand alone for a cold agent on the merged tree; that's the instruction set. Merge both sections into one combined worklist rather than treating them as separate passes — a dependency followup is addressed exactly like any other.

Present the list back to the user first — one line per followup (`[N/total] {necessity} {category}: {title}`), tagging which section each came from if both are present — so it's clear what's about to happen. Then work through them **one at a time, pausing after each** for the user to inspect the change and give feedback (see below). The followups were already accepted upstream, so don't ask permission *before* starting an item — the pause is for reviewing the result.

## Address each followup

Work through the followups in order (most necessary first, as recorded), **one subagent per
followup, one at a time** — never in parallel, since they share this worktree. Each handoff
prompt was written for a cold agent, so give it exactly that: a fresh `Agent` (general-purpose)
whose prompt is the handoff prompt verbatim, plus this preamble:

> You are working in `<absolute worktree path>`, a checkout of `<org>/<repo>` on the merged
> default branch; stay inside it. The tree may have moved since this followup was written:
> read the named files first and confirm the prompt's assumptions still hold. If the work is
> already done or no longer applies, change nothing and say why. Treat the acceptance
> criteria as the definition of done and the scope guard as a hard boundary. Verify the
> acceptance criteria where it's cheap (build, relevant tests, re-grep). Do not commit. If
> the prompt is genuinely ambiguous or risky in a way it doesn't resolve, change nothing and
> report the question instead of guessing. End with: status (done / skipped / blocked),
> files changed, acceptance criteria verified or not, and any open question.

For a **probe** followup (`Mode: probe`), replace the "Treat the acceptance criteria…"
sentences of the preamble with: *"This is a probe: the tests are throwaway, written only to
exercise the functionality and find real bugs. Delete them before finishing. Change
implementation files only to fix a bug you have confirmed is real, and keep that fix minimal.
If no real bug turns up, change nothing. For each bug, report the failing case (input,
expected, actual) so it can be kept as a regression test if wanted."* Its status is `done`
(bugs found and fixed), `done — no bugs found`, or `blocked`.

Wait for each subagent before starting the next. Before each one, snapshot the tree (`GIT_INDEX_FILE=<scratchpad>/idx git add -A && GIT_INDEX_FILE=<scratchpad>/idx git write-tree`) and again after, so that item's changes are exactly `git diff-tree -p <before> <after>` (this also attributes changed files to it, and lets the item be undone with `git apply -R` without touching earlier items). If one comes back blocked on a
question, raise it with `AskUserQuestion`; on an answer, re-run that followup's subagent
with the answer appended, otherwise record it as skipped. 
### Pause after each followup

When a subagent finishes, show the user: the followup title and status, a one-line summary,
files changed, the acceptance criteria verified or not, and the item's diff (abbreviated if
long; mention the full `git diff-tree -p` command). For a probe that found nothing, say so —
there is no diff. Then `AskUserQuestion`:

- **Continue** — accept the change as is and move on to the next followup.
- **Revise** — the user gives feedback (free text or via "Other"). Re-run that followup's
  subagent with the feedback appended and the current state described, on top of the existing
  changes, then pause again on the new diff.
- **Undo** — reverse-apply this item's patch and record it as skipped.
- **Stop** — end the run here; remaining followups are recorded as not attempted.

Never start the next followup until the user has answered. This replaces any "continue?"
batching — one item, one pause.

## After all followups

1. Print a tally: addressed vs. skipped (with a one-clause reason for each skip). List probes separately: bugs found and fixed vs. no bugs found (the latter leave no changes).
2. List the files modified, grouped by followup.
3. Note any acceptance criteria you couldn't verify and why.
4. **Do not commit** — the user decides when and how to commit (followups may warrant separate commits).
