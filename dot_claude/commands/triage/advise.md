---
description: Suggest concrete maintainer actions for a triaged issue, based on the saved triage, current issue state, and any linked work
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Advise on next actions

`TRIAGE.md` already captures a verdict and findings for this issue — from `/triage:save`, possibly kept current by `/triage:refresh`. This command doesn't re-triage. It answers a narrower question: **what should I, as maintainer, actually do next** — comment, label, close, link a PR, escalate — given the verdict, the current live state of the issue, and anything that's happened since.

Output is a short menu of concrete actions, each with the literal `gh`/`git` command that would carry it out. Never run a state-changing command yourself — comments, closes, label edits, and assignments are visible to others. Present them and stop; only execute one if the user explicitly says to.

## Establish context

Determine the issue and repo like `/triage:refresh`:
- Branch is typically `N-triage` — extract `N`.
- `<org>/<repo>` from git remotes (prefer `upstream`, fall back to `origin`).

If the worktree doesn't correspond to a triaged issue, say so and stop.

Read `TRIAGE.md` in the repository root. Parse frontmatter (`issue`, `state`, `labels`, `main_sha`, `triaged_at`, `verdict`) and the `## Findings` / `## Checked` / `## Next steps` / `## Open questions` sections. If a `recommended_rereview`-style staleness signal exists (a `/triage:refresh` run that recommended full re-triage but hasn't happened), note it — advice built on a stale triage should say so up front.

If `TRIAGE.md` doesn't exist, tell the user there's nothing to advise on yet (`/triage:refresh` or the triage workflow itself must run first) and stop.

## Gather current state (parallel, read-only)

Batch these:

1. **Live issue state** — `gh issue view <N> --repo <org>/<repo> --json state,title,labels,assignees,milestone,closedAt,comments -q .`. Compare `state`/`labels` against the frontmatter to see what's moved since triage.
2. **Cross-referenced PRs/issues** — `gh api repos/<org>/<repo>/issues/<N>/timeline --jq '.[] | select(.event == "cross-referenced" or .event == "connected")'`. For any referenced PR, `gh pr view <M> --repo <org>/<repo> --json state,title,mergeable,reviewDecision -q .` to see if it resolves this issue.
3. **Comments since `triaged_at`** — `gh api repos/<org>/<repo>/issues/<N>/comments --jq '.[] | select(.created_at > "<triaged_at>")'` (skip if `/triage:refresh` already folded these in and `triaged_at` is current — check the timestamp first, don't redo work).
4. **Duplicate/related candidates** — only if verdict is `duplicate` or a Findings entry tagged `related-issue` lacks a confirmed canonical issue: `gh issue list --repo <org>/<repo> --search "<title keywords> in:title,body" --state all --json number,title,state` to find the likely canonical issue.
5. **Repo conventions** — glance at `CONTRIBUTING.md` / `.github/ISSUE_TEMPLATE` / label list (`gh label list --repo <org>/<repo>`) only if the advice needs to reference a specific label, triage process, or escalation channel (e.g. SIG, Slack) the repo documents. Don't fetch this speculatively.

## Build the action menu, keyed by verdict

Cross-reference the verdict against what's actually happened since triage — a verdict can be overtaken by events (e.g. `needs-info` where the author already replied, or `duplicate` where the canonical issue has since closed).

- **needs-info**: If the requested info arrived in a new comment, the advice is "re-triage with the new info" (point at `/triage:refresh`), not another ask. If nothing arrived and enough time has passed (use judgement, not a fixed threshold), suggest a follow-up ping or a stale-close per repo convention. Otherwise: draft the exact comment asking for the missing info (pull the specific ask from `## Open questions`).
- **accepted**: Suggest the labels that make it discoverable/actionable (`help wanted`, `good first issue`, area/component labels — check against `gh label list` and the issue's current labels, don't suggest ones already applied), whether it needs a milestone/project assignment, and whether a linked PR already exists (in which case: review it, don't duplicate effort). If nothing is in flight, note that plainly rather than inventing an action.
- **duplicate**: Confirm (or find, per step 4 above) the canonical issue. Draft the exact close comment linking it, and the `gh issue close` / label commands.
- **not-a-bug** / **wontfix**: Draft the exact close comment (rationale drawn from the triage's `## Analysis`/findings, not generic), and the close/label commands.
- **needs-discussion**: Identify where that discussion belongs if the repo documents a venue (SIG meeting, mailing list, Slack channel, design-doc process) — from repo conventions gathered above, not invented. Otherwise suggest tagging specific stakeholders (from `CODEOWNERS`, recent commits to the affected area, or repo docs) in a comment.

If the live state already shows the action was effectively taken (issue closed, PR merged, label applied) since triage, say so instead of suggesting it again.

## Present the menu

For each suggested action: one line of rationale tying it to a specific finding or piece of live evidence, then the literal command block (`gh issue comment <N> --repo <org>/<repo> --body "..."`, `gh issue close <N> --repo <org>/<repo> --comment "..."`, `gh issue edit <N> --repo <org>/<repo> --add-label "..."`, etc.) ready to copy-paste or hand back for execution. Order by what most changes the issue's disposition first (close/link > label > comment > ping).

If nothing has changed and the existing `## Next steps` in `TRIAGE.md` still fully covers it, say that plainly — don't manufacture busywork.

## Persist into TRIAGE.md

Record the advice in place so a later `/triage:advise` run doesn't repeat stale reasoning. Add/update an `advice:` block in the frontmatter:

```yaml
advice:
  advised_at: <ISO 8601 UTC, Z suffix>   # date -u -Iseconds | sed 's/+00:00/Z/'
  based_on_triaged_at: <triaged_at this advice used>
```

And add/update an `## Advice` section in the body (after `## Next steps`, before `## Open questions`): the action menu as presented, each item with its rationale and command. On re-runs, replace the previous `## Advice` section rather than appending. Update `TRIAGE.html` to match if it exists — mirror the section with the same styling conventions as the rest of the file.

Generate the timestamp during the gather phase, not as a separate step before the edit.

## Output discipline

Do all gathering and the artifact edit first, without narrating between tool calls. Then print one summary as the last thing:

- What changed since triage, in a few bullets (state, new comments, linked PRs) — or "no change since triage" if that's the case.
- The action menu, in the order presented above, each with its command.
- The absolute path(s) of `TRIAGE.md` (and `TRIAGE.html` if updated).

Be specific — names, labels, SHAs, PR numbers, exact command text. No emoji, no filler. Never claim an action was taken; every item here is a suggestion awaiting explicit go-ahead.
