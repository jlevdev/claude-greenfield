#!/bin/bash
# Fetches everything on a PR that might need a decision -- unresolved
# review threads, un-surfaced top-level comments, and any condition
# currently blocking merge -- and returns only the ones not already
# decided. Deterministic fetch/filter/bookkeeping lives here rather than
# in prose so it's reliable across repeated invocations instead of the
# model re-deriving "what's open" by reasoning about raw JSON each time.
#
# Two modes:
#   find-open-issues.sh <pr-number> <owner> <repo> <state-file-path>
#     Fetch mode (default). Read-only -- does NOT write to the state
#     file. Returns open threads/comments/blocking conditions.
#   find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> mark <thread|comment> <id>
#     Mark mode. Records one specific thread or comment ID as decided.
#     Call this *after* actually acting on an item (Step 5), never
#     before -- marking-then-maybe-acting was a real bug (found via the
#     pr-review skill, CodeRabbit's review of PR #3, 2026-08-14: this
#     script used to mark everything decided the instant fetch mode
#     returned it, so a session that stopped before acting on an item
#     made it vanish on the next run. Confirmed live mid-session -- 9
#     threads had to be recovered via a raw GraphQL query after an
#     accidental second fetch call silently ate them).
#
# Blocking conditions (merge conflicts, blocked/dirty state, changes
# requested, failing CI) are never filtered by decided-state at all --
# they're states, not discrete events, and a still-failing CI check
# must never go silent just because it was seen (or dismissed) on an
# earlier scan. There is deliberately no "mark blocking as decided"
# mode. (Also found via the pr-review skill, same review round: the
# previous version tracked decided_blocking_keys and would hide an
# ongoing failure after the first scan saw it.)
#
# Known limitation, not silently hidden: a review thread is tracked by
# its stable thread ID, so a *new reply* landing in an already-decided
# thread does not resurface it. Best-effort, not a guarantee.

set -euo pipefail

PR_NUM="${1:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> [mark <thread|comment> <id>]}"
OWNER="${2:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> [mark <thread|comment> <id>]}"
REPO="${3:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> [mark <thread|comment> <id>]}"
STATE_FILE="${4:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> [mark <thread|comment> <id>]}"
MODE="${5:-fetch}"

mkdir -p "$(dirname "$STATE_FILE")"
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"decided_thread_ids": [], "decided_comment_ids": []}' > "$STATE_FILE"
fi

if [[ "$MODE" == "mark" ]]; then
  TYPE="${6:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> mark <thread|comment> <id>}"
  ID="${7:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> mark <thread|comment> <id>}"
  STATE=$(cat "$STATE_FILE")
  case "$TYPE" in
    thread)
      NEW_STATE=$(jq --arg id "$ID" '.decided_thread_ids = ((.decided_thread_ids // []) + [$id] | unique)' <<< "$STATE")
      ;;
    comment)
      NEW_STATE=$(jq --arg id "$ID" '.decided_comment_ids = ((.decided_comment_ids // []) + [$id] | unique)' <<< "$STATE")
      ;;
    *)
      echo "find-open-issues.sh: unknown mark type '$TYPE' (expected 'thread' or 'comment')" >&2
      exit 1
      ;;
  esac
  echo "$NEW_STATE" > "$STATE_FILE"
  exit 0
fi

# --- fetch mode: read-only from here on, no writes to $STATE_FILE ---

STATE=$(cat "$STATE_FILE")
CORE=$(gh pr view "$PR_NUM" --json number,title,url,state,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,comments)

# REST (`gh pr view --json`) has no isResolved field -- only the GraphQL
# API exposes review-thread resolution state. Paginated: a PR can
# accumulate more than 100 review threads over its lifetime, and a
# fixed first-100 fetch would silently omit unresolved threads sitting
# on a later page. Real gap found via the pr-review skill (CodeRabbit's
# review of PR #3), 2026-08-14.
THREADS="[]"
CURSOR=""
while true; do
  if [[ -z "$CURSOR" ]]; then
    PAGE=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                isResolved
                isOutdated
                comments(first: 10) {
                  nodes { author { login } body path line createdAt }
                }
              }
            }
          }
        }
      }' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUM" \
      --jq '.data.repository.pullRequest.reviewThreads')
  else
    PAGE=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!, $cursor: String!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100, after: $cursor) {
              pageInfo { hasNextPage endCursor }
              nodes {
                id
                isResolved
                isOutdated
                comments(first: 10) {
                  nodes { author { login } body path line createdAt }
                }
              }
            }
          }
        }
      }' -f owner="$OWNER" -f repo="$REPO" -F pr="$PR_NUM" -f cursor="$CURSOR" \
      --jq '.data.repository.pullRequest.reviewThreads')
  fi
  # `--argjson` passes its value as a single command-line argument, which
  # Linux caps around 128KB (MAX_ARG_STRLEN) regardless of the much
  # larger overall ARG_MAX -- a PR with many/large review comments (this
  # one, after a few rounds of CodeRabbit review, comfortably exceeds it)
  # blew this up with "Argument list too long". `--slurpfile` reads via
  # file I/O instead, with no such per-argument limit. Real bug found
  # live, immediately after the previous fix that introduced it, when
  # this script was run again as part of the same pr-watch pass.
  THREADS=$(jq --slurpfile page <(printf '%s' "$PAGE") '. + $page[0].nodes' <<< "$THREADS")
  HAS_NEXT=$(jq -r '.pageInfo.hasNextPage' <<< "$PAGE")
  [[ "$HAS_NEXT" != "true" ]] && break
  CURSOR=$(jq -r '.pageInfo.endCursor' <<< "$PAGE")
done

DECIDED_THREADS=$(jq -c '.decided_thread_ids' <<< "$STATE")
DECIDED_COMMENTS=$(jq -c '.decided_comment_ids' <<< "$STATE")

OPEN_THREADS=$(jq -c --slurpfile decided <(printf '%s' "$DECIDED_THREADS") '
  [.[] | select(.isResolved == false)
       | select(.id as $id | $decided[0] | index($id) == null)
       | {id, path: .comments.nodes[0].path, line: .comments.nodes[0].line,
          author: .comments.nodes[0].author.login, body: .comments.nodes[0].body,
          replyCount: (.comments.nodes | length)}]
' <<< "$THREADS")

NEW_COMMENTS=$(jq -c --slurpfile decided <(printf '%s' "$DECIDED_COMMENTS") '
  [.comments[] | select(.id as $id | $decided[0] | index($id) == null)
               | {id, author: .author.login, body}]
' <<< "$CORE")

# Always computed fresh, never filtered by prior "decided" state -- see
# file header. A blocking condition is a state, not an event.
BLOCKING=$(jq -c '
  ([
    (select(.mergeable == "CONFLICTING") | {key: "mergeable:CONFLICTING", desc: "Merge conflicts must be resolved"}),
    (select(.mergeStateStatus == "BLOCKED") | {key: "mergeStateStatus:BLOCKED", desc: "Merge is blocked (required checks or reviews not satisfied)"}),
    (select(.mergeStateStatus == "DIRTY") | {key: "mergeStateStatus:DIRTY", desc: "Merge conflicts present"}),
    (select(.reviewDecision == "CHANGES_REQUESTED") | {key: "reviewDecision:CHANGES_REQUESTED", desc: "A reviewer requested changes"})
  ]) as $simple |
  ([.statusCheckRollup[]? | select((.conclusion // .state) as $s | $s == "FAILURE" or $s == "ERROR")]) as $failing |
  $simple + (if ($failing | length) > 0
             then [{key: ("ci:" + ($failing | map(.name) | join(","))),
                    desc: ("CI checks failing: " + ($failing | map(.name) | join(", ")))}]
             else [] end)
' <<< "$CORE")

# Same MAX_ARG_STRLEN reasoning as the pagination merge above --
# $open_threads in particular can hold full comment bodies for every
# currently-open thread and has already been observed exceeding 128KB
# on this PR mid-review. `--slurpfile` for anything that could be more
# than a few KB; plain `--argjson` is fine only for genuinely small,
# bounded values (there are none of those left in this call).
jq -n \
  --slurpfile core <(printf '%s' "$CORE") \
  --slurpfile open_threads <(printf '%s' "$OPEN_THREADS") \
  --slurpfile new_comments <(printf '%s' "$NEW_COMMENTS") \
  --slurpfile blocking <(printf '%s' "$BLOCKING") \
  '
  ($core[0]) as $core |
  ($open_threads[0]) as $open_threads |
  ($new_comments[0]) as $new_comments |
  ($blocking[0]) as $blocking |
  {
    title: $core.title,
    url: $core.url,
    state: $core.state,
    mergeable: $core.mergeable,
    mergeStateStatus: $core.mergeStateStatus,
    reviewDecision: $core.reviewDecision,
    open_thread_count: ($open_threads | length),
    new_comment_count: ($new_comments | length),
    blocking_count: ($blocking | length),
    open_threads: $open_threads,
    new_comments: $new_comments,
    blocking: $blocking
  }'
