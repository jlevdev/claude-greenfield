#!/bin/bash
# Shared helper sourced by protect-files.sh and guard-secret-reads.sh, so
# the two hooks (block writing secrets, block reading secrets) can't drift
# out of sync with each other.

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROTECTED_PATTERNS_FILE="$LIB_DIR/protected-patterns.txt"

# Explicit exceptions: files that match a pattern above by substring but
# are meant to be read/edited normally (e.g. .env.example documents which
# vars exist, per CLAUDE.md's env var conventions). Compared case-folded,
# same reasoning as check_protected_path below.
_is_allowed_exception() {
  local lower
  lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')
  case "$lower" in
    .env.example|.env.sample) return 0 ;;
    *) return 1 ;;
  esac
}

# check_protected_path <file_path>
# Prints the matched pattern and returns 0 if the path is protected;
# returns 1 (silently) if it's fine to proceed.
check_protected_path() {
  local file_path="$1"
  local base
  base=$(basename -- "$file_path")

  _is_allowed_exception "$base" && return 1
  [[ -f "$PROTECTED_PATTERNS_FILE" ]] || return 1

  # Case-folded substring match -- Linux filesystems are case-sensitive so
  # '.ENV' is technically a different file than '.env', but nothing stops
  # someone naming a secrets file that way, and the original case-sensitive
  # compare missed it. Found by bypass-testing.
  local lower_path
  lower_path=$(echo "$file_path" | tr '[:upper:]' '[:lower:]')

  while IFS= read -r pattern; do
    [[ -z "$pattern" || "$pattern" == \#* ]] && continue
    local lower_pattern
    lower_pattern=$(echo "$pattern" | tr '[:upper:]' '[:lower:]')
    if [[ "$lower_path" == *"$lower_pattern"* ]]; then
      echo "$pattern"
      return 0
    fi
  done < "$PROTECTED_PATTERNS_FILE"

  return 1
}
