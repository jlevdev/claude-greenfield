---
allowed-tools: Bash(git fetch:*), Bash(git branch:*), Bash(git worktree:*), Bash(git remote:*)
description: Delete local branches and worktrees whose remote branch has been deleted
---

## Context
- Branches and their upstream tracking state: !`git branch -vv`
- Worktrees: !`git worktree list`

## Steps
1. Run `git fetch --prune` to update remote-tracking branches.
2. From the `git branch -vv` output above (re-run it after the prune), identify every local branch marked `: gone]`.
3. For each one, check whether it's checked out in a worktree (see the list above). If so, remove the worktree first: `git worktree remove <path>`.
4. Delete the branch: `git branch -D <name>`.
5. Report what was removed. If nothing was gone, say so explicitly — that's a good result, not a no-op to apologize for.

## Safety
- Never delete the current branch or the repository's default branch (`main`/`master`), even if it somehow shows as gone.
- If more than 5 branches would be deleted at once, list them and confirm with the user before deleting any.
- This only touches branches whose *remote* is already gone — it never deletes a remote branch or force-pushes anything itself.
