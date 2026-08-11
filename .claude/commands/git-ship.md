---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git checkout:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(gh pr create:*), Bash(gh pr view:*)
description: Commit, push, and open a PR in one step
---

## Context
- Current branch: !`git branch --show-current`
- Git status: !`git status`
- Staged and unstaged changes: !`git diff HEAD`

## When to use
Use this instead of running `/git-branch`, `/git-commit`, and `/git-pr` separately when a ticket is fully implemented, tested, and ready to ship in one motion. For incremental commits during development, use `/git-commit` alone — don't open a PR before the ticket is actually done.

## Steps
1. If the context above shows the current branch is `main` (or the repository's default branch per `CLAUDE.md`), create a feature branch first, following the `/git-branch` naming conventions. If the branch type/slug isn't obvious from context, ask.
2. Stage and commit using the `/git-commit` conventions — conventional commit format, ticket ID reference, and its safety checks (never stage `.env`/secrets, flag unrelated changes).
3. Push the branch: `git push -u origin <branch>`.
4. Open a PR using the `/git-pr` template and conventions.
5. Report the PR URL.

## Safety
- Never push directly to `main`/`master` — always via a branch and PR. The `git-safety.sh` hook already blocks this at the tool-call level; if it fires, that's a signal to branch properly, not a bug to route around (e.g. by force-pushing or a refspec trick).
- Confirm with the user before force-pushing under any circumstance.
- If `scan-commit-diff.sh` blocks the commit step, resolve that before continuing — do not skip straight to push.
