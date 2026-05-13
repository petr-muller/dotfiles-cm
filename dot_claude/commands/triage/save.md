---
description: Save the triage just performed as TRIAGE.html (for humans) and TRIAGE.md (for agents)
allowed-tools: Write, Read, Bash
---

# Save the triage

Produce two artifacts in the repository root, with **identical content** in two formats:

- `TRIAGE.html` — for me to open in a browser as a reference while engaging with the issue (commenting, linking PRs, deciding next steps).
- `TRIAGE.md` — for a future agent (`/triage:refresh`) to consume. Compact, structured, not for human reading.

Same findings and verdict in both. Different *encoding*, same *information*.

## Required metadata in BOTH files

At the top, embed:
- Issue identifier: `org/repo#N`
- Issue title
- Issue state at triage time: `open` or `closed`
- Labels at triage time (comma-separated)
- Triage timestamp in ISO 8601, **UTC with `Z` suffix** (`date -u -Iseconds | sed 's/+00:00/Z/'`). Must match GitHub's timestamp format exactly so `/triage:refresh` can compare it lexicographically against `created_at`/`submitted_at` values from the GitHub API.
- Main SHA at triage time (the worktree is on the `<N>-triage` branch which was reset to upstream default — `git rev-parse HEAD`)
- The triage verdict (one of: `needs-info`, `accepted`, `duplicate`, `not-a-bug`, `wontfix`, `needs-discussion`)

In HTML, render this as a header block. In MD, use YAML frontmatter:

```yaml
---
issue: org/repo#N
title: "..."
state: open
labels: bug, area/foo
main_sha: <full-sha>
triaged_at: 2026-05-13T17:49:00+02:00
verdict: accepted
---
```

`/triage:refresh` parses this frontmatter — keep keys and shape exact.

## TRIAGE.html

Single self-contained HTML (no external CSS/JS, no network requests). Sans-serif body, monospace for code, comfortable line-height, max-width on text columns.

Sections, in order:

1. **Header** — metadata above plus a link to the issue on GitHub.
2. **Verdict** — one-line bottom line and a one-paragraph rationale.
3. **What the issue reports** — 3-5 bullets in my own words. Not a copy of the issue body.
4. **Analysis** — the meat. Subsections as needed: *Reproducibility / observed behavior*, *Probable cause*, *Related code* (`file:line-range` references with brief excerpts), *Related issues / PRs* (with links and one-line each).
5. **What I checked** — short list, so I don't re-investigate.
6. **Recommended next steps** — concrete actions: ask the author X, link to PR Y, label as Z, escalate, etc.
7. **Open questions** — phrased as comments I might leave on the issue.

## TRIAGE.md

Optimized for agent parsing. Rules:

- YAML frontmatter as above.
- Compact. No filler, no emoji, no marketing tone.
- Findings as a flat list of structured entries:

```markdown
## Findings

### [reproducibility] short title
- detail: one or two sentences.
- evidence: `file:line-range` or external reference.

### [cause] short title
...

### [related-code] short title
- where: `file/path.go:42-58`
- excerpt: |
    actual code lines

### [related-issue] short title
- ref: org/repo#456
- relevance: one sentence.

### [related-pr] short title
- ref: org/repo#789
- relevance: one sentence.
```

Tags: `reproducibility`, `cause`, `related-code`, `related-issue`, `related-pr`. Use exactly those tokens — `/triage:refresh` matches on them.

- Then short flat sections:

```markdown
## Checked
- thing 1
- thing 2

## Next steps
- step 1
- step 2

## Open questions
- question 1
```

## Style rules (apply to both files)

- Be specific. Names, paths, SHAs, line ranges.
- Quote actual code or comment text, not paraphrases.
- If uncertain, say so explicitly.
- Don't restate the issue body verbatim — point to *what matters*.

## After writing

Print only the two absolute paths, one per line. No commentary.
