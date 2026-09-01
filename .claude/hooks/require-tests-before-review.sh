#!/bin/bash
# Runs the project's test suite before a ticket file is allowed to move into
# a tickets/**/review/ folder. Registered as a PreToolUse hook on Bash,
# unconditionally -- scoping is done internally below (checking the command
# for a tickets/**/review/ path) rather than via the dispatcher's "if" field,
# which previously scoped this to `mv`/`git mv` but false-positives on any
# Bash command containing brace-expansion syntax. See HANDOFF.md and
# scan-commit-diff.sh's header comment for the full story; this script
# already self-scoped before that was found, so no behavior changes here --
# only the now-redundant "if" fields were removed from settings.json/
# hooks.json.
#
# This makes /implement's "confirm the full test suite still passes" step
# (see .claude/commands/implement.md) enforced rather than just instructed.
#
# Best-effort: if no test command can be detected — expected for this
# template before it's scaffolded into a real project — it warns and lets
# the move through instead of blocking on nothing.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on moves that land in a tickets/**/review/ folder.
if ! echo "$COMMAND" | grep -qE 'tickets/(features|remediation)/review/'; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0

detect_test_command() {
  if [[ -f package.json ]]; then
    if grep -q '"test"' package.json && ! grep -q 'Error: no test specified' package.json; then
      if [[ -f pnpm-lock.yaml ]]; then echo "pnpm test"; return; fi
      if [[ -f yarn.lock ]]; then echo "yarn test"; return; fi
      if [[ -f bun.lockb ]]; then echo "bun test"; return; fi
      echo "npm test"
      return
    fi
  fi
  if [[ -f pyproject.toml || -f pytest.ini || -f setup.cfg ]]; then
    echo "pytest"
    return
  fi
  if [[ -f Cargo.toml ]]; then
    echo "cargo test"
    return
  fi
  if [[ -f go.mod ]]; then
    echo "go test ./..."
    return
  fi
  echo ""
}

TEST_CMD=$(detect_test_command)

if [[ -z "$TEST_CMD" ]]; then
  echo "require-tests-before-review: no test command detected yet, allowing the move. Once a stack is chosen (see CLAUDE.md), this hook will run it automatically before tickets can reach review/." >&2
  exit 0
fi

echo "require-tests-before-review: running '$TEST_CMD' before allowing move into review/..." >&2

LOG_FILE=$(mktemp)
if ! (eval "$TEST_CMD") > "$LOG_FILE" 2>&1; then
  echo "Blocked: '$TEST_CMD' failed, so this ticket can't move to review/ yet. Last 40 lines of output:" >&2
  tail -n 40 "$LOG_FILE" >&2
  rm -f "$LOG_FILE"
  exit 2
fi

rm -f "$LOG_FILE"
exit 0
