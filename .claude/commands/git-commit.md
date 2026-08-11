---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git branch:*)
description: Stage and commit changes using a conventional commit message
---

## Context
- Current git status: !`git status`
- Staged and unstaged changes: !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits (match this repo's style and ticket-ref conventions): !`git log --oneline -10`

## Conventional commit format
`<type>(<scope>): <short description>`

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`
**Scope:** the area of the codebase affected (e.g., `auth`, `map`, `api`, `ui`)
**Description:** imperative mood, under 72 characters, no period at the end

Examples:
- `feat(auth): add JWT refresh token flow [feat-3]`
- `fix(map): correct off-by-one in zoom level calculation [rem-2]`
- `test(travel): add edge cases for zero-distance journeys`

## Steps
1. From the context above, identify what changed and the commit type.
2. If the user did not specify which files to stage, ask — or confirm "everything" if they say so.
3. Reference ticket IDs in the message when applicable (append `[feat-N]` or `[rem-N]`).
4. Add a commit body if the change needs more context beyond the subject line.
5. Stage the specified files and commit. Never use `--no-verify`.

## Safety checks
- Never stage `.env` files, secrets, credentials, or large binaries.
- If unrelated changes are mixed in, flag them and ask whether to split into multiple commits.
- Warn if the diff is unexpectedly large for the stated ticket scope.
- The `scan-commit-diff.sh` hook blocks the commit itself if the staged diff matches a known-dangerous pattern (hardcoded secrets, eval/exec on dynamic input, disabled TLS verification, etc.). If it fires, read its message, fix or justify the flagged lines, and retry — don't try to route around it.
