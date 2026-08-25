---
allowed-tools: Bash(git fetch:*), Bash(git branch:*), Bash(git worktree:*), Bash(git remote:*), Bash(git log:*), Bash(git checkout:*), Bash(git stash:*), Bash(git pull:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git mv:*), Bash(gh pr list:*), Bash(gh pr view:*), Read, Edit, Write, Glob
description: Delete local branches and worktrees whose remote branch has been deleted, and close out any tickets that branch shipped
---

## Context
- Branches and their upstream tracking state: !`git branch -vv`
- Worktrees: !`git worktree list`
- Current branch: !`git branch --show-current`
- Default branch: !`git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}'`

## Steps
1. Run `git fetch --prune` to update remote-tracking branches.
2. From the `git branch -vv` output above (re-run it after the prune), identify every local branch marked `: gone]`.
3. For each gone branch, **before deleting anything**, check whether it shipped any tickets:
   a. **Resolve whether this branch actually merged** — a gone remote alone doesn't distinguish a merge from an abandoned branch: `gh pr list --state merged --head <branch> --json number,title,url,mergedAt`. No merged PR found → do not touch any ticket or the changelog for this branch; fold it into the confirm-before-delete list (see Safety) rather than assuming it's safe to clean up. Found → continue to 3b.
   b. Extract ticket IDs from **that merged PR's own record**, not the local branch — a local `git log <default-branch>..<branch>` range is unreliable here: this repo merges via a real merge commit (confirmed against its own history — `git log --merges`), so a merged branch's commits are already ancestors of the default branch and the range comes back empty every time; a squash-merge workflow would break it the opposite way. Pull the PR's own commits and body instead: `gh pr view <number> --json commits,body --jq '[.commits[].messageHeadline, .commits[].messageBody, .body] | join("\n")'`, grepping the result for `[feat-N]`/`[rem-N]` tags (the `git-commit` convention). No matches → nothing to close out for this branch, skip to step 4.
   c. For each ticket ID found: `Glob` for `tickets/{features,remediation}/review/<id>-*.md`. Not found there → check `done/` (already closed by a prior run, nothing to do) before concluding it's missing; if genuinely not found anywhere, note that in the final report rather than guessing why.
4. Before writing any ticket/changelog changes (step 5), make sure the working tree actually has them to move: they live on the default branch, post-merge. If the current branch isn't the default branch, stash any uncommitted work (`git stash`), check out the default branch, and pull. If a ticket file from step 3c still can't be found after that, local `main` may be missing the merge commit for another reason — report it plainly rather than guessing, and don't invent the file.
5. For every ticket confirmed in step 3: move its file from `review/` to the sibling `done/` folder (`git mv`), then append one entry to `CHANGELOG.md` — right after the marker comment near the top, **replacing** the `*No shipped changes yet.*` placeholder line if it's still there rather than leaving it in place above the new entries — with the date, ticket ID, a one-line summary drawn from the ticket's `## Description`, and the merged PR's URL from step 3a. Batch every ticket closed this run into it.
6. If step 5 changed anything: `git add` the moved ticket files and `CHANGELOG.md`, commit with a conventional message listing what shipped (e.g. `chore(tickets): close out feat-3, rem-2 (merged)`), then `git push`. If the push fails (protected branch, diverged history, etc.), stop there, report the failure clearly, and leave the commit local rather than retrying blindly — the ticket/changelog state is correct locally even if unpushed.
7. If step 4 switched off the original branch, return to it now (`git checkout -`, then `git stash pop` if something was stashed).
8. For each gone branch not held back by step 3a's merge check: check whether it's checked out in a worktree (see the list above). If so, remove the worktree first: `git worktree remove <path>`.
9. Delete the branch: `git branch -D <name>`.
10. Report: branches removed, tickets moved to `done/` (with their new changelog lines), any branches held back pending confirmation, and whether the bookkeeping commit pushed cleanly. If nothing was gone, say so explicitly — that's a good result, not a no-op to apologize for.

## Safety
- Never delete the current branch or the repository's default branch (`main`/`master`), even if it somehow shows as gone.
- If more than 5 branches would be deleted at once, list them and confirm with the user before deleting any. Also list, separately, any branch step 3a couldn't confirm as merged — deleting those needs the same explicit confirmation regardless of the 5-branch threshold, since "gone but unconfirmed" is exactly the case that risks silently losing an abandoned-but-unmerged branch's only copy.
- This only touches branches whose *remote* is already gone — it never deletes a remote branch or force-pushes anything itself.
- Ticket-closing (steps 3-7) only ever reads `tickets/**/review/` and `done/` and `CHANGELOG.md` — it never edits ticket content, only moves the file and appends a changelog line.
