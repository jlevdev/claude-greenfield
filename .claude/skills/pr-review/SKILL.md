---
name: pr-review
description: This skill should be used when the user asks to review a pull request, review a PR, review this branch before merging, get a second opinion on a PR, or says "/pr-review". Runs a read-only, severity-tagged review using parallel specialized subagents; never edits code, approves, merges, or posts PR comments unless separately asked.
argument-hint: <PR number or branch (optional — defaults to the current branch's PR)>
allowed-tools: [Read, Grep, Glob, Agent, "Bash(gh pr:*)", "Bash(git log:*)", "Bash(git diff:*)", "Bash(git branch:*)"]
version: 1.0.0
---

# PR Review

Review a pull request for correctness bugs, error-handling gaps, and — when the PR references tickets — acceptance-criteria and test-coverage completeness. Read-only, severity-tagged, no side effects.

This is distinct from `implement`'s reviewer gate: that one runs mid-development, blocking, on a single ticket's diff, before it ever reaches `review/`. This skill runs on a finished PR — anyone's, not just Claude's own — after the fact, and never blocks anything.

## What this skill never does
- Never edits code or applies fixes
- Never approves, requests changes, merges, or closes the PR
- Never posts comments to GitHub unless the user explicitly asks for that as a separate step, after seeing the findings first
- Never launches `/code-review ultra` on its own — that's a billed, user-triggered cloud review; mention it as an option, don't invoke it

## Step 1 — Resolve the target and gather context
- If no argument was given, use the current branch's PR: `gh pr view --json number,title,body,url,baseRefName`
- If a PR number or branch was given, resolve that instead: `gh pr view <target> --json number,title,body,url,baseRefName`
- Get the diff: `gh pr diff <number>` (fall back to `git diff <base>...<branch>` if `gh` can't resolve it — e.g. no PR exists yet for this branch)
- Get the commit list: `gh pr view <number> --json commits`, or `git log <base>..<branch> --oneline`

## Step 2 — Detect ticket references
Parse the PR body's `Closes:`/`Tickets:` line (see the `git-pr` command's PR template) and each commit message's `[feat-N]`/`[rem-N]` tags for ticket IDs. This determines which subagents run in Step 3 — don't skip it even for a PR that looks purely technical; a reference might sit in a commit the PR title doesn't reflect.

## Step 3 — Launch specialized subagents in parallel
Always:
- **`silent-failure-hunter`** — error handling, swallowed exceptions, unjustified fallbacks
- **`pr-correctness-reviewer`** — general bugs and `CLAUDE.md` compliance, confidence-scored, no ticket required

Only if Step 2 found ticket IDs, additionally launch per referenced ticket:
- **`ticket-reviewer`** — diff against that ticket's acceptance criteria and scope
- **`test-coverage-reviewer`** — behavioral test coverage against that ticket's acceptance criteria

Give every subagent the PR diff up front, and the relevant ticket file contents where applicable — don't make them re-derive context already gathered in Steps 1-2.

## Step 4 — Consolidate and tag severity
Merge every subagent's findings into one list. Each subagent uses its own internal scale (BLOCKING/NOTE, CRITICAL/HIGH/MEDIUM, 0-100 confidence) — reconcile them here onto one shared scale rather than reporting them separately:
- 🔴 **Important** — any BLOCKING/CRITICAL finding, or confidence ≥80
- 🟡 **Nit** — any NOTE/HIGH/MEDIUM finding, or confidence 50-79
- Drop anything below that. This skill defaults to the conservative end of the coverage/confidence trade-off on purpose — a noisy review trains people to stop reading it.

Deduplicate: if two subagents flag the same file:line for essentially the same reason, report it once and note which agents agreed — agreement across independent passes is itself a confidence signal, worth surfacing rather than hiding.

Cap it: report at most 8 🟡 Nits inline; beyond that, give a count and the dominant theme ("+6 more, mostly naming — ask to see the full list") instead of dumping all of them. No cap on 🔴 Important findings — every one of those needs to reach the user.

## Step 5 — Report
```
## PR Review: #<number> — <title>

<one-line tally, e.g. "3 Important, 5 Nit, ticket coverage OK">

### 🔴 Important
- `file:line` — <finding> (flagged by: <agent(s)>)

### 🟡 Nit
- `file:line` — <finding>
(+N more, mostly <theme> — ask to see the full list)

### Ticket cross-check (only if Step 2 found ticket IDs)
- feat-N: acceptance criteria <met / gaps> — <ticket-reviewer summary>
- feat-N: test coverage <ok / gaps> — <test-coverage-reviewer summary>
```
If nothing of substance was found, say so plainly and briefly — don't manufacture Nits to look thorough; that's exactly the noise Step 4 exists to filter out.

## Step 6 — Offer next steps, don't take them
Ask what the user wants to do with the findings: fix now, post as PR comments (`gh pr comment` or `gh pr review --comment`, only on explicit request), or leave as-is. If the PR looks like it needs deeper, whole-codebase-context analysis than a local diff review can give, mention `/code-review ultra` as an option rather than running it.
