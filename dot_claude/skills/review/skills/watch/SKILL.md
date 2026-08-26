---
name: watch
description: Watch a PR you authored for CI failures and review feedback, and converge towards green CI and resolved feedback
---

# Watch and converge my own PR

See `../../CONVENTIONS.md` for the shared Fibonacci-backoff loop pattern and output
discipline used by this skill and `/review:autopilot`.

Run this from the worktree/branch that authored the PR (a `work::claude` session, typically). This is a **long-running, self-pacing** command — invoke it as `/loop /review:watch` (no interval, so `/loop` self-paces via `ScheduleWakeup`). One cycle = gather signal, act on it, print a summary, schedule the next wakeup. The command keeps cycling until the PR is merged or closed.

Don't re-derive everything from scratch each cycle: this is one continuous session, so keep a running mental record (across cycles, not written to disk) of which CI failures, review comments, and threads you've already handled, dismissed-with-explanation, or deferred — only re-examine an item if it changed (new reply, new push touching it) since you last looked at it.

## Establish context (first cycle only)

Determine the PR from the current branch:

```
gh pr view --json number,url,headRefName,baseRefName,state,isDraft,mergeable,reviewDecision -q .
```

`<org>/<repo>` from the git remotes (`origin`, or `upstream` if this repo uses that split). If there's no open PR for the current branch, tell the user and stop — don't schedule a wakeup.

## Each cycle: gather signal

Batch these (all read-only):

1. **CI status** — `gh pr checks <N> --json name,state,bucket,link,description -q .` (or `gh pr checks <N>` if `--json` isn't supported by the installed `gh`). Note failing, pending, and passing checks.
2. **Reviews** — `gh api repos/<org>/<repo>/pulls/<N>/reviews --jq '.[] | select(.state != "PENDING")'`.
3. **Inline review comments** — `gh api repos/<org>/<repo>/pulls/<N>/comments` (group threaded replies under the root comment).
4. **Issue-level comments** — `gh api repos/<org>/<repo>/issues/<N>/comments` (skip bot noise unless it's a genuine CI/status bot report).
5. **PR state** — merged/closed, current head SHA, mergeable/reviewDecision.

If the PR is merged or closed: print a short closing summary (final CI state, what was addressed across the session) and call `ScheduleWakeup` with `stop: true`. Done — no further cycles.

## Triage what's new

For each CI failure, reviewer comment, or thread you haven't already handled this session:

### Failing CI

Investigate the actual failure (fetch logs via `gh run view`, or the repo's own CI-investigation skills if this is an OpenShift CI repo — check `.claude/skills/ci:*` availability). Find the root cause, not just the symptom. Fix it in the code. If a failure is flaky/infra-related and unrelated to this change, say so in the cycle summary and don't chase it — note it as "unrelated flake, not addressing" instead of endlessly retrying.

### Review feedback (inline comments, review bodies, issue comments)

Assess like `/review:address` would: read the actual code the comment refers to, form your own opinion, then choose one of three dispositions:

- **Address it** — the feedback is correct and worth doing. Make the code change.
- **Push back with an explanation** — the feedback is a nit taken too far, or would force an unnecessary tradeoff, or you disagree for a concrete technical reason. Don't silently ignore it: reply on the thread (`gh api repos/<org>/<repo>/pulls/<N>/comments/<comment_id>/replies -f body=...` for inline threads, or `gh pr comment <N> --body ...` for issue-level feedback) explaining *why* you're not doing it. Be concrete and respectful, not dismissive.
- **Defer to a followup PR** — valid but large/out-of-scope for this PR. Reply saying so explicitly (name roughly what the followup would cover), don't just drop it.

Never leave a piece of actionable feedback completely unacknowledged. Silence reads as ignoring the reviewer.

## Commit and push

Batch all the code fixes decided above into one or a few commits with clear, specific messages (what was fixed and why — not "address feedback"). Don't put a bare `#N` in the commit message (GitHub auto-cross-references it into every other issue/PR that gets tagged similarly; say `PR 123` if you need to reference it at all).

Push the branch (`git push`). If push fails (e.g. sandbox identity lacks access), say so plainly in the cycle summary rather than silently giving up — the user needs to know a push didn't land.

## Decide the next wakeup: fibonacci backoff

Use the shared backoff counter from `../../CONVENTIONS.md`. Here, "activity" is a new CI
check result (pass/fail/newly pending), a new commit/comment/review from someone else, or
an action *you* took (pushed a fix, replied to a thread).

Call `ScheduleWakeup` with `delaySeconds` = counter minutes × 60, `prompt` set to the same `/loop` invocation text the user used to start this (typically `/review:watch`), and a one-sentence `reason` naming what you're waiting for and the current backoff step (e.g. "no activity, backing off to 5 min").

## Output discipline

Do all gathering, investigation, edits, commits, and replies **first**, without narrating between tool calls (see the shared output-discipline pattern). Then print **one** summary as the last thing before scheduling the wakeup:

- CI state (pass/fail/pending, per check if any are failing).
- What was addressed this cycle (files changed, one line each).
- What was pushed back on, with a one-line reason each.
- What was deferred to a followup, with a one-line reason each.
- Anything still waiting on the reviewer or on CI.
- The current backoff counter and the next wakeup interval.

No emoji, no filler, no "great progress!". If nothing changed since the last cycle, say so in one line and move straight to scheduling the next wakeup.
