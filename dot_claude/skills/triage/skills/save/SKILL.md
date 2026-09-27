---
name: save
description: Save the triage just performed as TRIAGE.md (for agents) and a rendered TRIAGE.html (for humans)
---

# Save the triage

See `../../CONVENTIONS.md` for context resolution, pagination, the render step, timestamps, and output discipline.

Write `TRIAGE.md` in the repository root, then generate `TRIAGE.html` from it:

```
python3 <skill-base-dir>/../../scripts/render.py TRIAGE.md
```

(`<skill-base-dir>` is this skill's base directory, given when the skill loads.)

- `TRIAGE.md` — the single source of truth. `/triage:refresh` and `/triage:advise` parse it,
  so keep keys, section names, and tags exact.
- `TRIAGE.html` — generated; I open it in a browser as a reference while engaging with the
  issue (commenting, linking PRs, deciding next steps). Never hand-write or hand-edit it.
  Everything a human should see must be in the MD body; use plain Markdown, no raw HTML.

Every `triage:*` skill that changes `TRIAGE.md` re-runs the renderer afterwards.

## Frontmatter

```yaml
---
issue: org/repo#N
title: "..."
state: open
labels: bug, area/foo
main_sha: <full-sha>
triaged_at: 2026-05-13T17:49:00Z
verdict: accepted
---
```

- `state` — `open` or `closed` at triage time. `labels` — comma-separated, at triage time.
- `main_sha` — `git rev-parse HEAD` (the `<N>-triage` branch is reset to the upstream default branch).
- `triaged_at` — UTC with a literal `Z` suffix (`date -u -Iseconds | sed 's/+00:00/Z/'`), so it
  compares lexicographically against GitHub's `created_at`/`submitted_at`.
- `verdict` — one of `needs-info`, `accepted`, `duplicate`, `not-a-bug`, `wontfix`, `needs-discussion`. `/triage:refresh` may later set `resolved`.

Later skills may add `refresh_log:`, `recommended_retriage:`, and `advice:` blocks.

## Body sections, in order

```
# Triage
## Verdict                  one line + one-paragraph rationale
## Resolution               (added by /triage:refresh when a merged PR sufficiently resolves the issue)
## What the issue reports   3-5 bullets in my words, not a copy of the issue body
## Re-triage recommended    (added by /triage:refresh)
## Findings                 tagged entries, see below
## Resolved                 findings later answered/resolved (moved, never deleted)
## Checked                  what I checked, so I don't re-investigate
## Next steps               concrete actions: ask the author X, link PR Y, label Z, escalate
## Advice                   (added by /triage:advise)
## Open questions           phrased as comments I might leave on the issue
```

Findings are a flat list; tags are exactly `reproducibility`, `cause`, `related-code`,
`related-issue`, `related-pr` — `/triage:refresh` matches on them:

```markdown
### [reproducibility] short title
- detail: one or two sentences.
- evidence: `file:line-range` or external reference.

### [related-code] short title
- where: `file/path.go:42-58`
- excerpt: |
    actual code lines

### [related-pr] short title
- ref: org/repo#789
- relevance: one sentence.
```

(`cause` entries use `detail`/`evidence`; `related-issue` uses `ref`/`relevance`.)

## Style rules

- Be specific. Names, paths, SHAs, line ranges.
- Quote actual code or comment text, not paraphrases.
- If uncertain, say so explicitly.
- Don't restate the issue body verbatim — point to *what matters*.
- Compact. No filler, no emoji, no marketing tone.

## After writing

Print only the two absolute paths, one per line. No commentary.
