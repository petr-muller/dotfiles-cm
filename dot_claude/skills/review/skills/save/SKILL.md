---
name: save
description: Save the review just performed as REVIEW.md (for agents) and a rendered REVIEW.html (for humans)
---

# Save the review

See `../../CONVENTIONS.md` for the full `REVIEW.md` schema (frontmatter fields, body section
order, severity tokens, style rules) — this skill is what *produces* the artifact that
schema describes.

Write `REVIEW.md` in the repository root, then generate `REVIEW.html` from it:

```
python3 <skill-base-dir>/../../scripts/render.py REVIEW.md
```

- `REVIEW.md` — the source of truth. `/review:refresh` and every other `review:*` skill
  parses it, so follow the schema exactly.
- `REVIEW.html` — generated; I open it in a browser while doing the actual code review on
  GitHub. Never hand-write it.

Get `head_sha` via `git rev-parse HEAD` in the worktree (checked out at the PR head).

## Section content

- **Verdict** — one-line bottom line, then a one-paragraph rationale.
- **What this PR does** — 3-5 bullets in my words, not a copy of the PR description.
- **Findings** — each with a short title, `where:` as `file:line-range`, the relevant
  excerpt as a `- excerpt: |` literal block, and 1-3 sentences of `concern:`.
- **Checked** — things I checked and was fine with, so I don't re-investigate.
- **Open questions** — phrased as comments I might leave for the author.

## After writing

Print only the two absolute paths, one per line. No commentary.
