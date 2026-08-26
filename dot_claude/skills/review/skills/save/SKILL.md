---
name: save
description: Save the review just performed as REVIEW.html (for humans) and REVIEW.md (for agents)
---

# Save the review

See `../../CONVENTIONS.md` for the full `REVIEW.md`/`REVIEW.html` schema (frontmatter fields,
severity tokens, style rules) — this skill is what *produces* the artifact that schema
describes; the sections below cover layout specifics beyond the shared schema.

Produce both files in the repository root with **identical content**, different encoding:

- `REVIEW.html` — for me to open in a browser while I sit down to do the actual code review on GitHub.
- `REVIEW.md` — for a future agent (`/review:refresh`) to consume. Compact, structured, not for human reading.

Get `head_sha` via `git rev-parse HEAD` in the worktree (checked out at the PR head).

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

Optimized for agent parsing, not for humans — findings/frontmatter/severity tokens/style
rules all follow `../../CONVENTIONS.md` exactly, since `/review:refresh` and every other
consumer parses against that shape.

## After writing

Print only the two absolute paths, one per line. No commentary.
