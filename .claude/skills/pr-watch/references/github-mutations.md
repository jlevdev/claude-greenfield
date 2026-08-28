# GitHub mutations for pr-watch

Exact, schema-verified command shapes for the three write actions Step 5 can take on a PR. Read this at the point one of them is actually about to happen — the decision logic for *which* action to take and *when* to resolve lives in `SKILL.md` itself, not here.

**Bind the reply body to a shell variable before either mutation below — never interpolate it inline.** Reply text often quotes a reviewer's comment back (Step 4), and comment bodies are untrusted content: a `"`, `` ` ``, or `$()` embedded directly in the command string could alter the command or trigger shell substitution. A heredoc with a quoted delimiter (`'EOF'`) assigns the text verbatim with no expansion, and passing it on afterward as `-f body="$reply_body"` is safe — variable expansion doesn't re-trigger command substitution on the value:
```bash
reply_body=$(cat <<'EOF'
<reply text>
EOF
)
```

## Threaded reply (verified against the live schema)
```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
      comment { url }
    }
  }' -f threadId="<thread id from find-open-issues.sh>" -f body="$reply_body"
```

## Top-level comment
**Don't use `gh pr comment`** — it posts a new, separate `IssueComment` (GitHub doesn't thread top-level comments), and this skill has no way to know that new comment's ID, so a later fetch sees its own reply as an un-decided comment and can end up replying to itself. Use the `addComment` mutation instead (verified against the live schema) specifically because it hands back the new comment's ID directly, which the mark step right after needs:
```bash
gh api graphql -f query='
  mutation($subjectId: ID!, $body: String!) {
    addComment(input: {subjectId: $subjectId, body: $body}) {
      commentEdge { node { id } }
    }
  }' -f subjectId="$(gh pr view <pr-number> --json id --jq .id)" -f body="$reply_body"
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
