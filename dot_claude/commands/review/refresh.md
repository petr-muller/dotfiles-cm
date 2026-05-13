---
description: Inspect PR activity since the last review, summarize, and either update artifacts or recommend a full re-review
allowed-tools: Read, Write, Edit, Bash
---

# Refresh the review

Determine what's changed in the PR since the last review captured by `/review:save`, summarize the development, and either update the existing artifacts with the new findings *or* recommend a full re-review if the changes are substantial.

## Inputs

Read `REVIEW.md` in the repository root. Parse its YAML frontmatter for:
- `pr` — `org/repo#N`, split into `<org>/<repo>` and `<N>`
- `head_sha` — the reviewed commit (call it `OLD_SHA`)
- `reviewed_at` — ISO 8601 timestamp

If `REVIEW.md` doesn't exist, tell the user there's nothing to refresh and stop.

## Gather what changed

Use `gh` (read-only) and `git` to collect, in parallel where possible:

1. **Current PR head** — `gh pr view <N> --repo <org>/<repo> --json headRefOid,state,title -q .` → `NEW_SHA`. Also note if the PR was closed or merged.
2. **New commits** — `git log --oneline OLD_SHA..NEW_SHA` (after `git fetch upstream pull/<N>/head` or `origin pull/<N>/head` to make sure NEW_SHA is local). If the PR was force-pushed and `OLD_SHA` no longer reachable, note that and fall back to `gh pr view --json commits`.
3. **Diff stats** — `git diff --stat OLD_SHA..NEW_SHA` (or equivalent via gh if needed).
4. **Issue comments added since `reviewed_at`** — `gh api repos/<org>/<repo>/issues/<N>/comments --jq '.[] | select(.created_at > "<reviewed_at>")'`.
5. **Review comments (inline) added since `reviewed_at`** — `gh api repos/<org>/<repo>/pulls/<N>/comments --jq '.[] | select(.created_at > "<reviewed_at>")'`.
6. **Reviews submitted since `reviewed_at`** — `gh api repos/<org>/<repo>/pulls/<N>/reviews --jq '.[] | select(.submitted_at > "<reviewed_at>")'`.

If `OLD_SHA == NEW_SHA` and there are no new comments/reviews → say "no activity since `<reviewed_at>`" and stop.

## Decide: update or recommend re-review

Use judgement. Lean toward "update in place" unless the changes are genuinely substantial. Recommend a full re-review *only* when:
- Significant new code was added (rough heuristic: >100 lines of net change, or a new file in a non-trivial path), AND those changes are in areas your existing findings touched, OR
- The author explicitly rewrote / force-pushed large sections (e.g. `OLD_SHA` not reachable from `NEW_SHA`, and the diff stats indicate a near-rewrite), OR
- New code introduces concepts not covered by the previous review at all (e.g. previous PR was Go-only, now adds a frontend).

Minor commits (typo fixes, comment replies, small targeted changes addressing prior findings) → **update in place**, don't recommend re-review.

## When updating in place

Modify `REVIEW.md` and `REVIEW.html` together. Keep them in sync.

1. Update the frontmatter / header:
   - `head_sha:` → `NEW_SHA`
   - `reviewed_at:` → now, in UTC with `Z` suffix (`date -u -Iseconds | sed 's/+00:00/Z/'`). Must match GitHub's timestamp format so subsequent refreshes can compare lexicographically.
   - Add (or extend) a `refresh_log:` list entry recording the previous `head_sha`, the new one, and a one-line summary of what was incorporated.
2. Update findings: resolve ones the new commits address (move them to a "Resolved" section, don't delete — they're useful history), add new ones surfaced by the new code or comments.
3. In the **What this PR does** section, append a short paragraph: "Since previous review: ..." with 1-3 bullets.
4. Save both files.

The HTML structure must remain consistent with `/review:save` output. The MD structure too — `/review:refresh` may run again later against its own output.

## When recommending re-review

Don't modify the artifacts. Print a concise summary to the user containing:
- What changed (a few bullets: file paths, scope, lines).
- Why this exceeds "update in place" (which trigger from the rules above fired).
- Suggested action: re-run `/review` (or whichever review skill they use) and then `/review:save`.

End with the literal string `RECOMMENDATION: full re-review` on its own line so it's easy to grep for.

## Output rules

- Be specific about what changed. Names, paths, SHAs, line counts.
- Don't repeat the existing findings — refer to them by title.
- No emoji, no filler.
- When updating, print only the two absolute paths and a one-line summary. When recommending re-review, print the summary described above.
