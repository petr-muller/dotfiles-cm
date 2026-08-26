---
name: refresh
description: Inspect PR activity since the last review, summarize, and either update artifacts or recommend a full re-review
---

# Refresh the review

See `../../CONVENTIONS.md` for the `REVIEW.md` schema and the shared output-discipline pattern.

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

Even though no re-review is being performed, record the recommendation itself in the artifacts — the findings and rationale that led to it are worth keeping, not just printed to a scrollback that disappears.

Do **not** touch `head_sha` or `reviewed_at` — nothing has actually been reviewed at `NEW_SHA` yet, so the baseline for the *next* refresh's diff must stay at the old review point. Instead:

1. Append an entry to a `recommended_rereview:` list in the frontmatter (create it if absent), newest last:
   - `at` — now, same UTC `Z`-suffixed format as `reviewed_at`.
   - `old_sha` / `new_sha`.
   - `reason` — a one-line summary of which trigger fired.
2. Add or extend a **Re-review Recommended** section in both `REVIEW.md` and `REVIEW.html` (newest entry first), each entry containing:
   - Timestamp and SHA range.
   - What changed: the same bullets as the printed summary (file paths, scope, lines).
   - Why this exceeds "update in place": which trigger from the rules above fired, spelled out (not just the trigger name — the actual reasoning, e.g. how new code diverges from prior findings).
   - Activity since the last review (comments/reviews/label changes), same as would appear in an in-place update.
3. Leave existing findings sections untouched — this is a log entry, not a findings update.
4. If a previous refresh already recommended re-review and it still hasn't happened, keep both entries (don't overwrite) so the history of repeated recommendations is visible.
5. Save both files.

Then print a concise summary to the user containing:
- What changed (a few bullets: file paths, scope, lines).
- Why this exceeds "update in place" (which trigger from the rules above fired).
- Suggested action: re-run `/review` (or whichever review skill they use) and then `/review:save` — which will reset `head_sha`/`reviewed_at` and clear the need to carry `recommended_rereview` forward.
- The two absolute file paths that were updated with the recommendation entry.

End with the literal string `RECOMMENDATION: full re-review` on its own line so it's easy to grep for.

## Output rules

Follow the shared silent-gather-then-single-summary discipline in `../../CONVENTIONS.md`.
Fetch the current timestamp (`date -u -Iseconds | sed 's/+00:00/Z/'`) during the gather
phase, not as a separate step before edits.

The one final summary must be self-contained:

**When updating in place**, include: whether code changed (`OLD_SHA` → `NEW_SHA`, or "no
code changes"), PR state change if any, activity bullets (who did what, when), and the two
absolute file paths that were updated.

**When recommending re-review**, include the summary described in "When recommending
re-review" above.

**When there's no activity**, just say so and stop. No files to list.

Be specific: names, paths, SHAs, line counts. Don't repeat existing findings — refer to
them by title. Minimize tool calls: batch parallel fetches, one edit per file when possible.
