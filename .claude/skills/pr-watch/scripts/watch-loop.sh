#!/bin/bash
# Polls a PR until it settles (CI finishes, no new review activity) or a
# new item appears. Used by pr-watch's Step 7 as the `Monitor` tool's
# command -- launch it with real arguments and nothing left to template.
# Replaces an inline heredoc that had to be hand-filled with placeholders
# before every run; SKILL.md used to warn explicitly that a literal
# `<...>` left in place was invalid shell syntax, not a hint the shell
# resolves on its own. A parameterized script can't have that failure
# mode.
#
# Usage: watch-loop.sh <pr-number> <owner> <repo> <state-file-path> <details-file-path>
#
# Emits exactly one line and exits:
#   "NEW: <n> item(s) -- see <details-file-path>"     -- new items found; full detail written there
#   "SETTLED: CI finished, nothing new across 2 consecutive checks"
#
# Polls every 30s. No overall timeout here -- the caller (Monitor) owns
# that; this loop runs until one of the two conditions above is true.
#
# Deliberately no `set -e`: this is a long-lived poll loop, not a
# discrete task, and a transient `gh` failure (rate limit, network blip)
# should be retried on the next tick, not kill a 20-minute background
# watch. Each polled command is individually guarded instead, per the
# Monitor tool's own poll-loop guidance.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PR_NUM="${1:?usage: watch-loop.sh <pr-number> <owner> <repo> <state-file-path> <details-file-path>}"
OWNER="${2:?usage: watch-loop.sh <pr-number> <owner> <repo> <state-file-path> <details-file-path>}"
REPO="${3:?usage: watch-loop.sh <pr-number> <owner> <repo> <state-file-path> <details-file-path>}"
STATE_FILE="${4:?usage: watch-loop.sh <pr-number> <owner> <repo> <state-file-path> <details-file-path>}"
DETAILS_FILE="${5:?usage: watch-loop.sh <pr-number> <owner> <repo> <state-file-path> <details-file-path>}"

stable=0
while true; do
  ci=$(gh pr checks "$PR_NUM" --json name,bucket 2>/dev/null || echo '[]')
  pending=$(echo "$ci" | jq -e 'any(.[]; .bucket=="pending")' >/dev/null 2>&1 && echo yes || echo no)

  result=$("$SCRIPT_DIR/find-open-issues.sh" "$PR_NUM" "$OWNER" "$REPO" "$STATE_FILE" 2>/dev/null) \
    || result='{"open_thread_count":0,"new_comment_count":0,"blocking_count":0}'
  total=$(echo "$result" | jq '.open_thread_count + .new_comment_count + .blocking_count' 2>/dev/null || echo 0)

  if [[ "$total" -gt 0 ]]; then
    echo "$result" > "$DETAILS_FILE"
    echo "NEW: $total item(s) -- see $DETAILS_FILE"
    exit 0
  fi

  if [[ "$pending" == "no" ]]; then stable=$((stable+1)); else stable=0; fi
  if [[ "$stable" -ge 2 ]]; then
    echo "SETTLED: CI finished, nothing new across 2 consecutive checks"
    exit 0
  fi

  sleep 30
done
