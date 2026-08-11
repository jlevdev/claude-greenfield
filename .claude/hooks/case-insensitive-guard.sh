#!/bin/bash
# Blocks Claude's Write tool from creating a file whose name collides with
# an existing file in the same directory when compared case-insensitively
# (e.g. writing Foo.ts next to foo.ts). Registered as a PreToolUse hook on
# the Write matcher in .claude/settings.json.
#
# Why: git's index is case-sensitive, but macOS and Windows filesystems are
# usually case-insensitive by default. Two files that only differ by case
# can both be committed and look fine in `git status`, then silently
# collide/shadow each other the moment a teammate checks the repo out on
# macOS or Windows.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ -z "$FILE_PATH" ]] && exit 0

DIR=$(dirname -- "$FILE_PATH")
BASE=$(basename -- "$FILE_PATH")

[[ -d "$DIR" ]] || exit 0

LOWER_TARGET=$(echo "$BASE" | tr '[:upper:]' '[:lower:]')

while IFS= read -r existing; do
  [[ "$existing" == "." || "$existing" == ".." ]] && continue
  [[ "$existing" == "$BASE" ]] && continue   # same file, not a collision

  LOWER_EXISTING=$(echo "$existing" | tr '[:upper:]' '[:lower:]')
  if [[ "$LOWER_EXISTING" == "$LOWER_TARGET" ]]; then
    echo "Blocked: '$FILE_PATH' only differs by case from the existing '$DIR/$existing'. That collides on case-insensitive filesystems (macOS, Windows) even though git tracks them as separate files. Ask the user how they want this named." >&2
    exit 2
  fi
done < <(ls -1a -- "$DIR" 2>/dev/null)

exit 0
