The user wants a plain-language summary of one or more tickets.

## Steps
1. Parse the ticket IDs from the user's input (e.g., `feat-1`, `feat-3`, `rem-2`).
2. For each ID, search all status subfolders to find the file:
   - `tickets/features/{todo,in-progress,on-hold,review,done}/`
   - `tickets/remediation/{todo,in-progress,on-hold,review,done}/`
3. For each ticket found, output:
   - **[ID] Title** *(status)*
   - What it does in 2-3 sentences — plain language, no jargon
   - Acceptance criteria as a bulleted list
   - Dependencies (if any)
   - Effort estimate and milestone (if set)
4. If an ID is not found in any folder, say so explicitly.

Keep the output scannable. No filler text.
