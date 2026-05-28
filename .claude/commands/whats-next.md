Give the user a clear overview of current and upcoming work.

## Steps
1. Read all tickets in:
   - `tickets/features/in-progress/`
   - `tickets/features/todo/`
   - `tickets/features/on-hold/`
   - `tickets/remediation/in-progress/`
   - `tickets/remediation/todo/`
   - `tickets/remediation/on-hold/`

2. Present in this structure:

### In Progress
Items currently being implemented. Note how long they've been in-progress if the `created` date suggests they've been here a while.

### Up Next — Features
Todo feature tickets, sorted by priority (critical → high → medium → low). If priorities are equal, use milestone order.

### Up Next — Remediation
Todo bug/debt tickets, same sort order. Critical bugs should always surface above medium-priority features.

### On Hold
Blocked items. For each, note what's blocking them — check the ticket's Dependencies section.

3. For each ticket: `**[ID]** Title — one-line description (effort: S/M/L/XL)`

4. Flag dependency chains that constrain ordering (e.g., "feat-3 must come before feat-5").

5. If there are 3+ todo items, suggest a sprint grouping — aim for a balanced set by effort (e.g., one L + two M, or four S items).

6. Call out any critical or high-priority remediation items that should be pulled into the next sprint.
