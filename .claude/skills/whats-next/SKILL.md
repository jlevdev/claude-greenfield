---
name: whats-next
description: This skill should be used when the user asks for a status overview, what to work on next, or a sprint summary — e.g. "what's next", "what should I work on", "give me a status update", "what's blocked" — or says "/whats-next".
allowed-tools: [Read, Glob, Grep]
effort: low
version: 1.1.0
---

# What's Next

Give the user a clear overview of current and upcoming work.

## Steps

1. Read all tickets in:
   - `tickets/features/in-progress/`
   - `tickets/features/todo/`
   - `tickets/features/on-hold/`
   - `tickets/remediation/in-progress/`
   - `tickets/remediation/todo/`
   - `tickets/remediation/on-hold/`

2. Read all files in `questions/open/` and note which tickets each question blocks.

3. Present in this structure:

### Open Questions
Any questions in `questions/open/`. For each: **[q-N]** the question, and which tickets it blocks. If there are none, omit this section.

### In Progress
Items currently being implemented. Note how long they've been in-progress if the `created` date suggests they've been here a while.

### Up Next — Features
Todo feature tickets, sorted by priority (critical → high → medium → low). If priorities are equal, use milestone order.

### Up Next — Remediation
Todo bug/debt tickets, same sort order. Critical bugs should always surface above medium-priority features.

### On Hold
Blocked items. For each, note what's blocking them — check the ticket's Dependencies section.

For each ticket: `**[ID]** Title — one-line description (effort: S/M/L/XL)`

4. Flag dependency chains that constrain ordering (e.g., "feat-3 must come before feat-5").
5. If an open question blocks a todo ticket, mark that ticket with ⚠️ in the output.
6. If there are 3+ todo items, suggest a sprint grouping — aim for a balanced set by effort (e.g., one L + two M, or four S items). Exclude tickets blocked by open questions from sprint suggestions.
7. Call out any critical or high-priority remediation items that should be pulled into the next sprint.
