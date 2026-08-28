---
name: implement
description: This skill should be used when the user asks to implement, build, or work on one or more tickets — e.g. "implement feat-3", "build rem-2", "let's start on feat-4 and feat-5" — or says "/implement". Enters test-driven implementation mode against this project's ticket workflow.
argument-hint: <feat-N|rem-N> [more ticket IDs...]
allowed-tools: [Read, Write, Edit, Bash, Glob, Grep, Agent, AskUserQuestion, EnterWorktree, ExitWorktree]
version: 1.2.1
---

# Implement Mode

Build one or more tickets using test-driven development.

## Pre-flight

1. Read `CLAUDE.md` — tech stack, conventions, constraints.
2. Read `PRD.md` — full project context and requirements.
3. Locate each ticket referenced (e.g., `feat-1`, `rem-2`). Search all status subfolders:
   - `tickets/features/{todo,in-progress,on-hold,review,done}/`
   - `tickets/remediation/{todo,in-progress,on-hold,review,done}/`
4. Check `questions/open/` for any open questions that list this ticket in their `blocks` field. If blocking questions exist, surface them to the user and stop — do not begin implementation until they are answered or explicitly waived.
5. **Worktree isolation (opt-in).** Check whether the session is already inside a *linked* worktree via git's own metadata, not a path guess — `git rev-parse --git-dir` and `git rev-parse --git-common-dir` are equal in a normal checkout and differ in any linked worktree, regardless of where it lives on disk:
   ```bash
   [[ "$(git rev-parse --git-dir 2>/dev/null)" != "$(git rev-parse --git-common-dir 2>/dev/null)" ]] && echo "already in a worktree"
   ```
   If already in one, skip this step entirely — don't nest. Otherwise ask via `AskUserQuestion`: *"Implement this in an isolated git worktree?"* — `No, use the current working tree` (recommended default) / `Yes, isolate in a worktree`. If yes:
   - Call `EnterWorktree` with `name` set to the ticket ID (or first ticket ID, if several — e.g. `feat-3`).
   - `EnterWorktree` always names the branch `worktree-<name>`, which doesn't match this project's `feat/<id>-<slug>` / `fix/<id>-<slug>` convention (see `git-branch.md`) — immediately rename it to match: `git branch -m <feat-or-fix>/<ticket-filename-stem>` (reuse the ticket file's own `<id>-<slug>` stem — e.g. ticket file `feat-3-user-auth.md` → branch `feat/feat-3-user-auth`; remediation tickets use `fix/` per the same convention). Remember this new name for the closing step below.

   Everything from here on — file moves, edits, tests, the reviewer-gate subagents in step 6 below, git commands — runs inside that worktree automatically, since it's a session-level directory switch, not something each step has to account for separately. This reduces the blast radius of a bad TDD cycle to a disposable branch instead of the working tree the user is actually looking at. Ask once per invocation, covering every ticket in this batch together, not per ticket.
6. Move each target ticket to the `in-progress` folder.
7. Scan existing source code to understand current patterns, naming conventions, and architecture.

## Implementation rules

- **TDD first:** write failing tests before writing implementation code. No exceptions.
- Work one ticket at a time unless tickets are explicitly independent and non-overlapping.
- If a genuine blocker is hit mid-implementation (ambiguous requirement, missing dependency, conflicting spec) that cannot be reasonably inferred: create a question file in `questions/open/` using `templates/question.md`, note which ticket it blocks, stop work on that ticket, and report to the user. Do not guess an answer that could require significant rework.
- Do not refactor unrelated code. Stay in scope.
- Follow the tech stack and conventions from `CLAUDE.md` exactly.

## TDD workflow per ticket

1. Read the ticket's acceptance criteria and "Test Coverage Required" section.
2. Write tests for each criterion — they must fail at this point.
3. Implement the minimum code to make the tests pass.
4. Confirm tests pass.
5. Refactor only within the scope of this ticket, keeping tests green.
6. **Reviewer gate:** launch the `ticket-reviewer`, `silent-failure-hunter`, and `test-coverage-reviewer` subagents in parallel against this ticket's diff. Each has its own verdict vocabulary — `ticket-reviewer`/`test-coverage-reviewer` output `BLOCKED` or `PASS`; `silent-failure-hunter` blocks only on a `CRITICAL` finding. Treat any of those (`BLOCKED` or `CRITICAL`) as blocking. If any agent blocks, fix it and **re-run all three agents** against the updated diff, not just the one that flagged — a fix for one agent's finding can introduce something a different agent would have caught. Proceed to step 7 only once all three are non-blocking. Carry every non-blocking note forward into step 9 under "Reviewer Notes" so the human reviewer sees them without re-running the same checks.
7. Move the ticket file to the `review` folder.
8. **If, and only if,** this ticket involved a genuine architectural or approach decision that isn't obvious from reading the resulting code and isn't already covered by an existing `DECISIONS.md` entry (e.g. "chose polling over a websocket for v1," "denormalized X for read performance") — not something ambiguous enough to have warranted a `questions/open/` blocker, but still worth a future reader knowing *why* the code is shaped this way: draft an ADR entry using the template in `DECISIONS.md` (skip entirely if `DECISIONS.md` doesn't exist yet at the project root — don't create it here, that's `start-project`'s job) and ask via `AskUserQuestion` (`Add to DECISIONS.md` / `Skip` / `Edit first`) before appending. Most tickets won't produce one of these — don't manufacture a decision to fill this step.
9. Summarize: what files changed, what tests were added, any decisions made (including whether one was recorded to `DECISIONS.md`), and the Reviewer Notes from step 6.

## When all requested tickets are finished

- Confirm the full test suite still passes.
- List all tickets moved to review.
- Note any follow-on work or new `rem-N` items discovered during implementation (create tickets for them in `todo` if warranted).
- **If this session entered a worktree in Pre-flight step 5**, ask via `AskUserQuestion`: *"Keep the worktree (review/push/PR from there — recommended) or remove it?"* — then call `ExitWorktree` with `action: "keep"` or `action: "remove"` accordingly (`remove` needs `discard_changes: true` if anything's uncommitted; confirm that's really wanted before passing it — it deletes the branch). Either way this returns the session to the original working tree.
  - **On `remove`, also explicitly delete the renamed branch** — `git branch -D <the feat/... or fix/... name from step 5>`. Verified this is actually needed, not just cautious: `ExitWorktree`'s own cleanup only reaches the branch under the `worktree-<name>` name it originally created, so after step 5's rename it silently leaves the renamed branch behind on disk. `ExitWorktree` still removes the worktree directory itself correctly either way — it's specifically the now-orphaned branch that needs this extra step.
  - If kept, the work stays on the worktree's branch, not the original tree's current branch — running `/git-pr` or `/git-ship` from here won't see it; re-enter the worktree (`EnterWorktree` with `path: <worktree path from the earlier confirmation message>`) to continue from there, or work from the branch directly with plain git commands.
