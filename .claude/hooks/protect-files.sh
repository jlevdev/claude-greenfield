#!/bin/bash
# Blocks Claude's Edit/Write tools from touching secrets, lockfiles, and VCS
# internals. Registered as a PreToolUse hook on the Edit|Write matcher in
# .claude/settings.json. Pattern list lives in lib/protected-patterns.txt,
# shared with guard-secret-reads.sh (the read-side counterpart).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/check-protected-path.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0

if MATCHED_PATTERN=$(check_protected_path "$FILE_PATH"); then
  echo "Blocked: '$FILE_PATH' matches protected pattern '$MATCHED_PATTERN'. Secrets and lockfiles should be changed by hand or via the proper tool (e.g. 'npm install'), not edited directly by an agent. Ask the user if this file genuinely needs to change." >&2
  exit 2
fi

exit 0
