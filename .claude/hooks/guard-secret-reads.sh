#!/bin/bash
# Blocks Claude's Read tool from opening secrets, lockfiles, and credential
# files — the read-side counterpart to protect-files.sh. Registered as a
# PreToolUse hook on the Read matcher in .claude/settings.json.
#
# Rationale: protect-files.sh stops secrets being *edited*, but does
# nothing to stop them being *read* and then echoed into a commit message,
# a PR description, or a later tool call. This closes that gap. Shares its
# pattern list with protect-files.sh via lib/protected-patterns.txt.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/check-protected-path.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0

if MATCHED_PATTERN=$(check_protected_path "$FILE_PATH"); then
  echo "Blocked: reading '$FILE_PATH' is not allowed (matches protected pattern '$MATCHED_PATTERN'). If you need a specific value from this file, ask the user to share just that value rather than reading the whole file." >&2
  exit 2
fi

exit 0
