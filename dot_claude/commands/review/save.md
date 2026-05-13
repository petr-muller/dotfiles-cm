---
description: Save the review just performed as REVIEW.html (for humans) and REVIEW.md (for agents)
allowed-tools: Write, Read, Bash
---

# Save the review

Produce two artifacts in the repository root, with **identical content** expressed in two formats:

- `REVIEW.html` — for me to open in a browser while I sit down to do the actual code review on GitHub.
- `REVIEW.md` — for a future agent (`/review:refresh`) to consume. Compact, structured, not for human reading.

Both files MUST cover the same findings, verdict, and observations. Different *encoding*, same *information*.

## Required metadata in BOTH files

At the very top, embed:
- PR identifier: `org/repo#N`
- PR title
- PR head SHA at review time (run `git rev-parse HEAD` in the worktree — it's checked out at the PR head)
- Review timestamp in ISO 8601, **UTC with `Z` suffix** (`date -u -Iseconds | sed 's/+00:00/Z/'`). Must match GitHub's timestamp format exactly so `/review:refresh` can compare it lexicographically against `created_at`/`submitted_at` values from the GitHub API.
- Base branch

In HTML, render this as a header block. In MD, use a YAML frontmatter block:

```yaml
---
pr: org/repo#N
title: "..."
head_sha: <full-sha>
base: main
reviewed_at: 2026-05-13T17:49:00+02:00
---
```

`/review:refresh` will parse this frontmatter, so keep the keys and shape exact.

## REVIEW.html

A single self-contained HTML file (no external CSS/JS, no network requests). Clean readable layout — sans-serif body, monospace for code, comfortable line-height, max-width on text columns.

Sections, in order:

1. **Header** — the metadata above plus a link to the PR on GitHub.
2. **Verdict** — one-line bottom line (approve / request changes / needs discussion) and a one-paragraph rationale.
3. **What this PR does** — 3-5 bullets, my-words summary (not a copy of the PR description).
4. **Findings** — grouped by severity: **Blocking**, **Should fix**, **Nits**, **Questions**. Each finding has a short title, `file:line-range` styled as code, the relevant excerpt (inline `<span>` styling is fine for highlighting, don't pull in a library), and 1-3 sentences explaining the concern.
5. **Things I checked and was fine with** — short list, so I don't re-investigate.
6. **Open questions for the author** — phrased as comments I might leave.

## REVIEW.md

Optimized for agent parsing. Not for humans. Rules:

- YAML frontmatter as specified above.
- Compact. No filler, no marketing tone, no "great PR overall!". No emoji. No restating obvious things.
- Findings as a flat list of structured entries, one per finding:

```markdown
## Findings

### [blocking] short title
- where: `file/path.go:42-58`
- concern: one or two sentences.
- excerpt: |
    actual code lines

### [should-fix] short title
...

### [nit] short title
...

### [question] short title
...
```

Severities: `blocking`, `should-fix`, `nit`, `question`. Use exactly those tokens — `/review:refresh` matches on them.

- After findings, two short sections:

```markdown
## Checked
- thing 1
- thing 2

## Open questions
- question 1
- question 2
```

- `verdict:` goes in frontmatter too: one of `approve`, `request-changes`, `needs-discussion`.

## Style rules (apply to both files)

- Be specific. "Consider refactoring" is useless; "the retry loop in `foo.go:42` will spin forever if `ctx` is already cancelled" is useful.
- Quote actual code, not paraphrases.
- If uncertain, say so explicitly.
- Don't repeat the diff verbatim — point to *where to focus*.

## After writing

Print only the two absolute paths, one per line. No commentary.
