---
description: Inspect issue activity since the last triage, summarize, and either update artifacts or recommend a full re-triage
allowed-tools: Read, Write, Edit, Bash
---

# Refresh the triage

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

1. **Current issue state** — `gh issue view <N> --repo <org>/<repo> --json state,title,labels,closedAt -q .`. Compare `state` and `labels` against frontmatter. Note if it transitioned open↔closed.
2. **New comments since `triaged_at`** — `gh api repos/<org>/<repo>/issues/<N>/comments --jq '.[] | select(.created_at > "<triaged_at>")'`. Extract author, timestamp, body.
3. **Linked PRs / cross-references** — `gh api repos/<org>/<repo>/issues/<N>/events --jq '.[] | select(.created_at > "<triaged_at>") | select(.event == "cross-referenced" or .event == "connected" or .event == "referenced")'`. List any new PR references.
4. **Optional — main branch movement** — `git fetch <upstream-or-origin>` then `git log --oneline OLD_MAIN_SHA..<remote>/<default-branch>` to note if upstream has advanced since triage. Useful when the triage referenced code that may have changed.

If state is unchanged, labels unchanged, no new comments, no new cross-references → say "no activity since `<triaged_at>`" and stop.

## Decide: update or recommend re-triage

Lean toward "update in place" unless changes are substantial. Recommend a full re-triage *only* when:
- Issue state changed (closed → reopened or vice versa) and the new state changes the recommended next steps, OR
- The author or maintainer added substantial new information that materially changes the analysis (e.g. new repro steps that contradict the previous reproducibility finding, a new error in a different subsystem), OR
- Scope changed: comments reveal the issue is actually about something different than originally triaged, OR
- A linked PR exists that now resolves the issue (verdict should change to reflect that).

Minor — label tweaks, "+1" comments, the author providing requested info that confirms the existing triage, small clarifications → **update in place**, don't recommend re-triage.

## When updating in place

Modify `TRIAGE.md` and `TRIAGE.html` together. Keep them in sync.

1. Update frontmatter / header:
   - `state:` and `labels:` → current values
   - `triaged_at:` → now, in UTC with `Z` suffix (`date -u -Iseconds | sed 's/+00:00/Z/'`). Must match GitHub's timestamp format so subsequent refreshes can compare lexicographically.
   - `main_sha:` → leave alone unless you re-fetched and re-anchored the analysis to a newer main
   - `verdict:` → only change if the new info actually warrants it
   - Add (or extend) a `refresh_log:` list entry recording the previous timestamp and a one-line summary of what was incorporated.
2. Update findings: append new ones surfaced by comments / events. If a previous finding was resolved by an answer in a comment, move it to a "Resolved" subsection (don't delete — history matters).
3. In the **What the issue reports** section, append a short "Since previous triage:" paragraph with 1-3 bullets.
4. Update **Recommended next steps** if the actions shifted.
5. Save both files.

The HTML structure must remain consistent with `/triage:save` output. The MD structure too — `/triage:refresh` may run again later against its own output.

## When recommending re-triage

Don't modify the artifacts. Print a concise summary to the user:
- What changed (a few bullets: state transitions, key new comments, new PR refs).
- Why this exceeds "update in place" (which trigger from the rules above fired).
- Suggested action: re-run the triage workflow and then `/triage:save`.

End with the literal string `RECOMMENDATION: full re-triage` on its own line so it's easy to grep for.

## Output rules

- Be specific. Names, timestamps, comment authors, PR numbers.
- Don't repeat existing findings — refer to them by title.
- No emoji, no filler.
- When updating, print only the two absolute paths and a one-line summary. When recommending re-triage, print the summary described above.
