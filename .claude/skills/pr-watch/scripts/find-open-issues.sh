#!/bin/bash
# Fetches everything on a PR that might need a decision -- unresolved
# review threads, un-surfaced top-level comments, and any condition
# currently blocking merge -- and returns only the ones this skill hasn't
# already surfaced. Deterministic fetch/filter/bookkeeping lives here
# rather than in prose so it's reliable across repeated invocations
# instead of the model re-deriving "what's open" by reasoning about raw
# JSON each time.
#
# Usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path>
#
# Every item this script returns is immediately recorded in the state
# file as "surfaced" -- once shown, an item is not returned again on a
# later run, regardless of what ends up done with it (fixed, replied-to-
# and-dismissed, or deliberately left as-is all count as "decided" once
# surfaced). Delete the state file (or pass `reset`, per the skill) to
# clear this and see everything again.
#
# Known limitation, not silently hidden: a review thread is tracked by
# its stable thread ID, so a *new reply* landing in an already-surfaced
# thread does not resurface it. Best-effort, not a guarantee.

set -euo pipefail

PR_NUM="${1:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path>}"
OWNER="${2:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path>}"
REPO="${3:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path>}"
STATE_FILE="${4:?usage: find-open-issues.sh <pr-number> <owner> <repo> <state-file-path>}"

mkdir -p "$(dirname "$STATE_FILE")"
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"decided_thread_ids": [], "decided_comment_ids": [], "decided_blocking_keys": []}' > "$STATE_FILE"
fi
STATE=$(cat "$STATE_FILE")

CORE=$(gh pr view "$PR_NUM" --json number,title,url,state,mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,comments)

# REST (`gh pr view --json`) has no isResolved field -- only the GraphQL
# API exposes review-thread resolution state.
THREADS=$(gh api graphql -f query='
  query($owner: String!, $repo: String!, $pr: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
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
  --jq '.data.repository.pullRequest.reviewThreads.nodes')
# Note: caps at 100 threads (no pagination). Fine for any PR of sane
# size; a PR with 100+ review threads has bigger problems than this
# script not paginating.

DECIDED_THREADS=$(jq -c '.decided_thread_ids' <<< "$STATE")
DECIDED_COMMENTS=$(jq -c '.decided_comment_ids' <<< "$STATE")
DECIDED_BLOCKING=$(jq -c '.decided_blocking_keys' <<< "$STATE")

OPEN_THREADS=$(jq -c --argjson decided "$DECIDED_THREADS" '
  [.[] | select(.isResolved == false)
       | select(.id as $id | $decided | index($id) == null)
       | {id, path: .comments.nodes[0].path, line: .comments.nodes[0].line,
          author: .comments.nodes[0].author.login, body: .comments.nodes[0].body,
          replyCount: (.comments.nodes | length)}]
' <<< "$THREADS")

NEW_COMMENTS=$(jq -c --argjson decided "$DECIDED_COMMENTS" '
  [.comments[] | select(.id as $id | $decided | index($id) == null)
               | {id, author: .author.login, body}]
' <<< "$CORE")

BLOCKING=$(jq -c --argjson decided "$DECIDED_BLOCKING" '
  ([
    (select(.mergeable == "CONFLICTING") | {key: "mergeable:CONFLICTING", desc: "Merge conflicts must be resolved"}),
    (select(.mergeStateStatus == "BLOCKED") | {key: "mergeStateStatus:BLOCKED", desc: "Merge is blocked (required checks or reviews not satisfied)"}),
    (select(.mergeStateStatus == "DIRTY") | {key: "mergeStateStatus:DIRTY", desc: "Merge conflicts present"}),
    (select(.reviewDecision == "CHANGES_REQUESTED") | {key: "reviewDecision:CHANGES_REQUESTED", desc: "A reviewer requested changes"})
  ]) as $simple |
  ([.statusCheckRollup[]? | select((.conclusion // .state) as $s | $s == "FAILURE" or $s == "ERROR")]) as $failing |
  ($simple + (if ($failing | length) > 0
              then [{key: ("ci:" + ($failing | map(.name) | join(","))),
                     desc: ("CI checks failing: " + ($failing | map(.name) | join(", ")))}]
              else [] end)) as $all |
  [$all[] | select(.key as $k | $decided | index($k) == null)]
' <<< "$CORE")

# Everything returned is now "shown" -- commit it to the decided set
# immediately, per the file header's documented behavior.
NEW_STATE=$(jq -n \
  --argjson prev "$STATE" \
  --argjson newThreadIds "$(jq -c '[.[].id]' <<< "$OPEN_THREADS")" \
  --argjson newCommentIds "$(jq -c '[.[].id]' <<< "$NEW_COMMENTS")" \
  --argjson newBlockingKeys "$(jq -c '[.[].key]' <<< "$BLOCKING")" \
  '{
    decided_thread_ids: (($prev.decided_thread_ids + $newThreadIds) | unique),
    decided_comment_ids: (($prev.decided_comment_ids + $newCommentIds) | unique),
    decided_blocking_keys: (($prev.decided_blocking_keys + $newBlockingKeys) | unique)
  }')
echo "$NEW_STATE" > "$STATE_FILE"

jq -n \
  --argjson core "$CORE" \
  --argjson open_threads "$OPEN_THREADS" \
  --argjson new_comments "$NEW_COMMENTS" \
  --argjson blocking "$BLOCKING" \
  '{
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
