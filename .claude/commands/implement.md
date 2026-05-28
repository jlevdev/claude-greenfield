You are entering **IMPLEMENT mode**. Your job is to build one or more tickets using test-driven development.

## Pre-flight
1. Read `CLAUDE.md` — tech stack, conventions, constraints.
2. Read `PRD.md` — full project context and requirements.
3. Locate each ticket the user referenced (e.g., `feat-1`, `rem-2`). Search all status subfolders:
   - `tickets/features/{todo,in-progress,on-hold,review,done}/`
   - `tickets/remediation/{todo,in-progress,on-hold,review,done}/`
4. **Check `questions/open/` for any open questions that list this ticket in their `blocks` field.** If blocking questions exist, surface them to the user and stop — do not begin implementation until they are answered or explicitly waived.
5. Move each target ticket to the `in-progress` folder.
6. Scan existing source code to understand current patterns, naming conventions, and architecture.

## Implementation rules
- **TDD first:** Write failing tests before writing implementation code. No exceptions.
- Work one ticket at a time unless tickets are explicitly independent and non-overlapping.
- If you hit a genuine blocker mid-implementation (ambiguous requirement, missing dependency, conflicting spec) that cannot be reasonably inferred: **create a question file** in `questions/open/` using `templates/question.md`, note which ticket it blocks, stop work on that ticket, and report to the user. Do not make up an answer or push through with a guess that could require significant rework.
- Do not refactor unrelated code. Stay in scope.
- Follow the tech stack and conventions from `CLAUDE.md` exactly.

## TDD workflow per ticket
1. Read the ticket's acceptance criteria and "Test Coverage Required" section.
2. Write tests for each criterion — they must fail at this point.
3. Implement the minimum code to make the tests pass.
4. Confirm tests pass.
5. Refactor only within the scope of this ticket, keeping tests green.
6. Move the ticket file to the `review` folder.
7. Summarize: what files changed, what tests were added, any decisions made.

## When you finish all requested tickets
- Confirm the full test suite still passes.
- List all tickets moved to review.
- Note any follow-on work or new `rem-N` items discovered during implementation (create tickets for them in `todo` if warranted).
