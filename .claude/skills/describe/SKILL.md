---
name: describe
description: This skill should be used when the user wants a plain-language summary of one or more tickets — e.g. "describe feat-3", "explain what rem-2 is about", "summarize feat-1 and feat-4" — or says "/describe".
argument-hint: <feat-N|rem-N> [more ticket IDs...]
allowed-tools: [Read, Glob, Grep]
version: 1.0.0
---

# Describe

Give the user a plain-language summary of one or more tickets.

## Steps

1. Parse the ticket IDs from the request (e.g., `feat-1`, `feat-3`, `rem-2`).
2. For each ID, search all status subfolders to find the file:
   - `tickets/features/{todo,in-progress,on-hold,review,done}/`
   - `tickets/remediation/{todo,in-progress,on-hold,review,done}/`
3. For each ticket found, output:
   - **[ID] Title** *(status)*
   - What it does in 2-3 sentences — plain language, no jargon
   - Acceptance criteria as a bulleted list
   - Dependencies (if any)
   - Effort estimate and milestone (if set)
   - ⚠️ **Blocked by:** list any open questions in `questions/open/` whose `blocks` field includes this ticket ID
4. If an ID is not found in any folder, say so explicitly.

Keep the output scannable. No filler text.
