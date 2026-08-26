# GitHub mutations for pr-watch

Exact, schema-verified command shapes for the three write actions Step 5 can take on a PR. Read this at the point one of them is actually about to happen — the decision logic for *which* action to take and *when* to resolve lives in `SKILL.md` itself, not here.

## Threaded reply (verified against the live schema)
```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
      comment { url }
    }
  }' -f threadId="<thread id from find-open-issues.sh>" -f body="<reply text>"
```

## Top-level comment
**Don't use `gh pr comment`** — it posts a new, separate `IssueComment` (GitHub doesn't thread top-level comments), and this skill has no way to know that new comment's ID, so a later fetch sees its own reply as an un-decided comment and can end up replying to itself. Use the `addComment` mutation instead (verified against the live schema) specifically because it hands back the new comment's ID directly, which the mark step right after needs:
```bash
gh api graphql -f query='
  mutation($subjectId: ID!, $body: String!) {
    addComment(input: {subjectId: $subjectId, body: $body}) {
      commentEdge { node { id } }
    }
  }' -f subjectId="$(gh pr view <pr-number> --json id --jq .id)" -f body="<reply text>"
```
Then mark **both** IDs decided — the original comment being replied to, and the new one this just created (from `commentEdge.node.id` in the response above) — or the new comment becomes next fetch's "new" item.

## Resolve a review thread
```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) { thread { isResolved } }
  }' -f threadId="<thread id>"
```
This is GitHub-side only. Always pair it with the local bookkeeping call so `find-open-issues.sh` doesn't re-surface the item:
```bash
.claude/skills/pr-watch/scripts/find-open-issues.sh <pr-number> <owner> <repo> <state-file-path> mark thread <thread id>
```
(or `mark comment <comment id>` for a top-level comment — top-level comments have no GitHub-side "resolve," only this local mark applies).
