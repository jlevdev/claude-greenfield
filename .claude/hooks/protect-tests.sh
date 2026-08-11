#!/bin/bash
# Blocks deleting a test file, renaming one out of test-naming, or silently
# disabling/removing test cases via Edit or Write. Registered as a
# PreToolUse hook on the Bash|Edit|Write matcher in .claude/settings.json —
# it branches on tool_name internally rather than needing three separate
# registrations.
#
# Rationale: .claude/commands/implement.md says "TDD first ... No
# exceptions." A test suite that shrinks or gets skipped is the easiest way
# to make a red suite look green without fixing anything.
#
# This is a heuristic, not a diff-aware linter — it will occasionally flag
# a legitimate refactor (e.g. consolidating two tests into one with more
# assertions). That's the intended trade-off: ask a human rather than guess.

is_test_path() {
  echo "$1" | grep -qEi '(^|/)(tests?|__tests__|spec)/|[._-](test|spec)\.[a-zA-Z0-9]+$|(^|/)test_[a-zA-Z0-9_]*\.py$'
}

# Filename-only version (ignores directory), used to detect the specific
# "rename it out of test-naming" trick even when the file stays in the
# same tests/ directory (e.g. test_foo.py -> test_foo.py.bak).
is_test_filename() {
  local base
  base=$(basename -- "$1")
  echo "$base" | grep -qEi '^test_[a-zA-Z0-9_]*\.py$|[._-](test|spec)\.[a-zA-Z0-9]+$|_test\.(go|rs)$'
}

SKIP_MARKERS='\.skip\(|xit\(|xdescribe\(|xtest\(|it\.skip\(|test\.skip\(|describe\.skip\(|@pytest\.mark\.skip|@unittest\.skip|pytest\.mark\.skip'

test_decl_count() {
  grep -Eo '\b(it|test)\s*\(|\bdescribe\s*\(|^\s*def\s+test_[a-zA-Z0-9_]*\s*\(' <<< "$1" | wc -l | tr -d ' '
}

skip_marker_count() {
  grep -Eo "$SKIP_MARKERS" <<< "$1" | wc -l | tr -d ' '
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

case "$TOOL_NAME" in
  Bash)
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    [[ -z "$COMMAND" ]] && exit 0

    if echo "$COMMAND" | grep -qE '\brm\b'; then
      for token in $COMMAND; do
        # Strip surrounding quote characters -- whitespace-based tokenizing
        # doesn't strip them, so `rm "tests/foo.spec.ts"` left the literal
        # quotes attached to the token and broke is_test_path's trailing
        # `$` anchor, letting any *quoted* test path through unblocked
        # (true even without a space in the path). Real bypass found via
        # code review, confirmed against this hook, fixed here. A path
        # containing an actual space still splits across tokens and isn't
        # caught -- documented known gap, see tests/bypass-test.sh.
        clean=$(echo "$token" | sed -E "s/^['\"]+//; s/['\"]+\$//")
        if is_test_path "$clean"; then
          echo "Blocked: '$COMMAND' deletes what looks like a test file ('$clean'). If it's genuinely obsolete, ask the user to confirm and remove it themselves." >&2
          exit 2
        fi
      done
    fi

    if echo "$COMMAND" | grep -qE '\b(mv|git mv)\b'; then
      REST=$(echo "$COMMAND" | sed -E 's/^.*\b(git mv|mv)\s+//')
      SRC=$(echo "$REST" | awk '{print $1}' | sed -E "s/^['\"]+//; s/['\"]+\$//")
      DST=$(echo "$REST" | awk '{print $2}' | sed -E "s/^['\"]+//; s/['\"]+\$//")
      if [[ -n "$SRC" && -n "$DST" ]] && is_test_filename "$SRC" && ! is_test_filename "$DST"; then
        echo "Blocked: '$COMMAND' renames a test file ('$SRC') to a name that test runners won't discover anymore ('$DST'). Ask the user before doing this." >&2
        exit 2
      fi
    fi
    ;;

  Edit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    is_test_path "$FILE_PATH" || exit 0

    OLD_STRING=$(echo "$INPUT" | jq -r '.tool_input.old_string // empty')
    NEW_STRING=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')

    OLD_DECLS=$(test_decl_count "$OLD_STRING")
    NEW_DECLS=$(test_decl_count "$NEW_STRING")
    OLD_SKIPS=$(skip_marker_count "$OLD_STRING")
    NEW_SKIPS=$(skip_marker_count "$NEW_STRING")

    if (( NEW_DECLS < OLD_DECLS )); then
      echo "Blocked: this edit removes $((OLD_DECLS - NEW_DECLS)) test case(s) from '$FILE_PATH'. If they're genuinely obsolete, ask the user to confirm." >&2
      exit 2
    fi
    if (( NEW_SKIPS > OLD_SKIPS )); then
      echo "Blocked: this edit adds a skip marker to a test in '$FILE_PATH'. Skipping a test isn't the same as fixing it — ask the user before disabling it." >&2
      exit 2
    fi
    ;;

  Write)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    is_test_path "$FILE_PATH" || exit 0
    [[ -f "$FILE_PATH" ]] || exit 0   # brand-new test file, nothing to compare against

    NEW_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
    OLD_CONTENT=$(cat "$FILE_PATH")

    OLD_DECLS=$(test_decl_count "$OLD_CONTENT")
    NEW_DECLS=$(test_decl_count "$NEW_CONTENT")
    OLD_SKIPS=$(skip_marker_count "$OLD_CONTENT")
    NEW_SKIPS=$(skip_marker_count "$NEW_CONTENT")

    if (( NEW_DECLS < OLD_DECLS )); then
      echo "Blocked: overwriting '$FILE_PATH' would drop $((OLD_DECLS - NEW_DECLS)) test case(s) ($OLD_DECLS -> $NEW_DECLS). If that's intentional, ask the user to confirm." >&2
      exit 2
    fi
    if (( NEW_SKIPS > OLD_SKIPS )); then
      echo "Blocked: overwriting '$FILE_PATH' adds skip markers to existing tests. Ask the user before disabling a test to reach green." >&2
      exit 2
    fi
    ;;
esac

exit 0
