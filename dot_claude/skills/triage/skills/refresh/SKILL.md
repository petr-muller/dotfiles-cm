---
name: refresh
description: Inspect issue activity since the last triage, summarize, and either update artifacts or recommend a full re-triage
---

# Refresh the triage

See `../../CONVENTIONS.md` for context resolution, pagination, the render step, timestamps, and output discipline.

Determine what's changed on the issue since the last triage captured by `/triage:save`, summarize the development, and either update the existing artifacts with new findings *or* recommend a full re-triage if the changes are substantial.

## Inputs

Read `TRIAGE.md` in the repository root. Parse its YAML frontmatter for:
- `issue` — `org/repo#N`, split into `<org>/<repo>` and `<N>`
- `state` — `open` or `closed` at triage time
- `labels` — comma-separated list at triage time
- `triaged_at` — ISO 8601 timestamp
- `main_sha` — main SHA at triage time (call it `OLD_MAIN_SHA`)

If `TRIAGE.md` doesn't exist, tell the user there's nothing to refresh and stop.

## Gather what changed

Use `gh` (read-only) to collect, in parallel where possible:

1. **Current issue state** — `gh issue view <N> --repo <org>/<repo> --json state,stateReason,title,labels,closedAt,closedByPullRequestsReferences -q .`. Compare `state` and `labels` against frontmatter. Note if it transitioned open↔closed, and for a close, the `stateReason` (`COMPLETED`, `NOT_PLANNED`, `DUPLICATE`) and any closing PRs.
2. **New comments since `triaged_at`** — `gh api --paginate repos/<org>/<repo>/issues/<N>/comments --jq '.[] | select(.created_at > "<triaged_at>")'`. Extract author, timestamp, body.
3. **Linked PRs / cross-references** — `gh api --paginate repos/<org>/<repo>/issues/<N>/timeline --jq '.[] | select(.created_at > "<triaged_at>") | select(.event == "cross-referenced" or .event == "connected" or .event == "referenced")'` (the timeline endpoint, not `/events` — cross-references only appear in the timeline). List any new PR references. For each referenced PR (and each closing PR from step 1), `gh pr view <M> --repo <org>/<repo> --json state,mergedAt,title,body,files -q .` — a linked PR that is still **open** is a fix in flight; a **merged** one is a (claimed) resolution.
4. **Optional — main branch movement** — `git fetch <upstream-or-origin>` then `git log --oneline OLD_MAIN_SHA..<remote>/<default-branch>` to note if upstream has advanced since triage. Useful when the triage referenced code that may have changed.

If state is unchanged, labels unchanged, no new comments, no new cross-references → say "no activity since `<triaged_at>`" and stop.

## Decide: update or recommend re-triage

Lean toward "update in place" unless changes are substantial. Recommend a full re-triage *only* when:
- The issue was **reopened** after being closed, OR
- The issue was closed by a merged PR (or as completed) and the **resolution check** below finds the fix insufficient, OR
- The author or maintainer added substantial new information that materially changes the analysis (e.g. new repro steps that contradict the previous reproducibility finding, a new error in a different subsystem), OR
- Scope changed: comments reveal the issue is actually about something different than originally triaged.

Minor — label tweaks, "+1" comments, the author providing requested info that confirms the existing triage, small clarifications → **update in place**, don't recommend re-triage.

A linked PR that is still **open** is not a trigger: update in place, noting the PR under "Since previous triage:" and in `## Next steps` (e.g. "review/track #M"), with one line on whether its approach matches the triage's findings and recommended next step.

An issue closed **without** a fix (`NOT_PLANNED`, `DUPLICATE`) is not a trigger either: update in place, recording the close reason and, for duplicates, the canonical issue.

### Resolution check

When the issue was closed by a merged PR, or a merged PR claims to fix it, re-triaging the original problem is pointless — the question is only whether the fix is *sufficient*. Read the PR (description, changed files, and `gh pr diff <M> --repo <org>/<repo>` for the relevant parts) against the triage's `## What the issue reports` and `cause`/`reproducibility` findings, plus any comments after the merge, and classify:

- **sufficient** — the PR addresses the reported problem at the cause the triage identified (or a convincingly argued different one), and nothing after the merge says otherwise. → update in place: `verdict: resolved`, add a `## Resolution` section.
- **partial** — the PR addresses only some reported symptoms/cases, a workaround rather than the cause, or comments say the problem persists. → recommend re-triage; the reason names what remains unaddressed.
- **unrelated / unclear** — the PR doesn't visibly touch the reported problem (e.g. auto-closed by a loose `Fixes` keyword). → recommend re-triage with that as the reason.

The `## Resolution` section: resolving PR(s) and merge date, the classification with 1-3 bullets of evidence (files/functions changed vs. the triaged cause), and whether it matches the previously recommended next step.

## When updating in place

Edit `TRIAGE.md`; the HTML is regenerated at the end.

1. Update frontmatter / header:
   - `state:` and `labels:` → current values
   - `triaged_at:` → now, in UTC with `Z` suffix (`date -u -Iseconds | sed 's/+00:00/Z/'`). Must match GitHub's timestamp format so subsequent refreshes can compare lexicographically.
   - `main_sha:` → leave alone unless you re-fetched and re-anchored the analysis to a newer main
   - `verdict:` → only change if the new info actually warrants it
   - Add (or extend) a `refresh_log:` list entry recording the previous timestamp and a one-line summary of what was incorporated.
2. Update findings: append new ones surfaced by comments / events. If a previous finding was resolved by an answer in a comment, move it to `## Resolved` (don't delete — history matters).
3. In `## What the issue reports`, append a short "Since previous triage:" paragraph with 1-3 bullets.
4. Update `## Next steps` if the actions shifted (for a sufficient resolution: typically none, or post-merge verification).
5. Save, then regenerate the HTML: `python3 <skill-base-dir>/../../scripts/render.py TRIAGE.md`.

Keep the MD structure consistent with `/triage:save` output — `/triage:refresh` may run again later against its own output.

## When recommending re-triage

Record the recommendation in the artifacts so it outlives the scrollback and `/triage:advise` can see the triage is stale. Do **not** touch `triaged_at`, `state`, `labels`, `main_sha`, or `verdict` — nothing has been re-triaged yet, so the next refresh must still diff from the old baseline. Instead:

1. Append an entry to a `recommended_retriage:` list in the frontmatter (create it if absent), newest last: `at` (now, UTC `Z` suffix), `since` (the `triaged_at` it was measured against), `reason` (one line: which trigger fired).
2. Add or extend a `## Re-triage recommended` section in `TRIAGE.md` (placement per `/triage:save`'s section order), newest entry first: timestamp, what changed, and why it exceeds "update in place" — the actual reasoning, not just the trigger name. Keep earlier entries if a previous recommendation was never acted on.
3. Leave existing findings untouched.
4. Save, then regenerate the HTML: `python3 <skill-base-dir>/../../scripts/render.py TRIAGE.md`.

`/triage:save` on the next full triage rewrites the file, which clears these entries.

Then print a concise summary to the user:
- What changed (a few bullets: state transitions, key new comments, new PR refs).
- Why this exceeds "update in place" (which trigger from the rules above fired).
- Suggested action: re-run the triage workflow and then `/triage:save`.
- The two absolute file paths that were updated.

End with the literal string `RECOMMENDATION: full re-triage` on its own line so it's easy to grep for.

## Output rules

- Be specific. Names, timestamps, comment authors, PR numbers.
- Don't repeat existing findings — refer to them by title.
- No emoji, no filler.
- When updating, print only the two absolute paths and a one-line summary. When recommending re-triage, print the summary described above.
