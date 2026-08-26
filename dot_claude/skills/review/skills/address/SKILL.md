---
name: address
description: Walk through PR review feedback one item at a time, deciding whether and how to address each piece
---

# Address PR review feedback

Gather all review feedback on the current PR, then walk the user through each item **one at a time**. For each item, present what the reviewer said, assess whether it makes sense to address, propose how if it does, and let the user decide before moving on.

## Prerequisites

Determine the PR number and repo from the worktree context — see `../../CONVENTIONS.md`
("Establishing PR/repo context from a worktree").

## Gather feedback

Fetch all review comments and reviews using `gh`:

```
gh api repos/<org>/<repo>/pulls/<N>/reviews --jq '.[] | select(.state != "PENDING")'
gh api repos/<org>/<repo>/pulls/<N>/comments
gh api repos/<org>/<repo>/issues/<N>/comments
```

From these, extract individual feedback items. A "feedback item" is:
- An inline review comment (or a thread — group threaded replies under the original comment).
- A review-level comment with body text (not just an empty "approved" or "commented" review).
- An issue-level comment that contains actionable feedback (skip pure discussion, "LGTM", CI bot output, etc.).

Skip:
- The PR author's own comments (that's the user — they don't need to address their own feedback).
- Bot comments (CI, linters, etc.) unless they contain a genuine failure the user should look at.
- Empty review bodies (GitHub creates a review object with empty body for inline-only reviews).
- Pure approval reviews with no body and no inline comments.

Sort items chronologically (oldest first). Group inline comments that are part of the same review thread — present the thread as one item, not N separate items.

## Walk through items one by one

For each feedback item, present it to the user with `AskUserQuestion`. Structure each presentation as follows:

### The question text

Format the question like this (adapt naturally, don't be robotic):

```
**[N/total] Feedback from @reviewer** (on `file/path.go:42`)

> quoted reviewer comment (abbreviated if very long — max ~5 lines, with "[...]" for omitted middle)

**Assessment:** [Your one-sentence take on whether this is a valid concern and why/why not.]

**Suggested action:** [If worth addressing: what specifically to change. If not: why it's fine to skip.]
```

For the assessment, actually look at the code the reviewer is commenting on. Read the relevant file and lines. Understand the reviewer's concern in context. Don't just parrot back what they said — form your own opinion on whether the feedback is correct and useful.

### The options

Use `AskUserQuestion` with these options:

- **"Address it"** — description: apply the suggested fix (or the reviewer's suggestion if yours doesn't apply). After the user picks this, make the code change immediately, then move to the next item.
- **"Skip"** — description: leave the code as-is for this item. Move to the next item.
- **"Discuss"** — description: talk about this item more before deciding. When the user picks this, engage in free-form conversation about the item. After the discussion, re-present the same item with `AskUserQuestion` (the user's discussion may change the suggested action).

If there's a clear-cut right answer (e.g., the reviewer pointed out an obvious bug), say so in the assessment — but still let the user decide.

## After addressing an item

When the user picks "Address it":

1. Make the code change.
2. Briefly confirm what was changed (one line, e.g., "Fixed — added nil check at `foo.go:47`.").
3. Move to the next item immediately. Don't ask "shall we continue?" — just present the next one.

## After all items

When all items have been walked through, print a short summary:
- How many items were addressed vs. skipped.
- List the files that were modified.
- Do NOT commit. The user will decide when to commit.

## Rules

- **One item at a time.** Never present multiple items in a single message.
- **Read the code** before assessing each item. Don't guess from the comment alone.
- **Be honest** in assessments. If the reviewer is wrong, say so. If they're right, say so. Don't be diplomatic to the point of being useless.
- **Don't batch.** Don't pre-read all files for all items upfront. Read as you go — keeps context focused.
- If the PR has no actionable feedback, say so and stop.
