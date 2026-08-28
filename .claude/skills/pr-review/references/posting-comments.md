# Posting PR comments (pr-review)

Exact command shape for Step 7's `Post as PR comment` action. Read this when findings are actually about to be posted, not before.

Draft the comment text for all selected findings, show the draft, then post.

## General comment (no specific file:line)

`gh pr comment`/`gh pr review --comment` only post general, top-level comments — neither has a flag for a line-anchored inline comment (verified: no `gh` CLI option exists for this). That's fine for a finding with no specific `file:line` to anchor to:
```bash
gh pr comment <number> --body "<drafted comment text>"
```

## Inline findings anchored to file:line

Batch them into **one** `gh api` call against `/repos/{owner}/{repo}/pulls/<number>/reviews` instead, with a `comments` array of `{path, line, side, body}` objects — one API call posting all of them as a single review, not one call per finding.

**`event` is required.** Without it, GitHub creates the review in `PENDING` state and the comments stay invisible until a separate submit call — the findings never actually get published (verified against GitHub's REST docs: a `reviews` POST with no `event` field defaults to `PENDING`). Use `event: "COMMENT"`:
```bash
cat > review.json <<'EOF'
{
  "body": "<drafted summary text>",
  "event": "COMMENT",
  "comments": [
    { "path": "<file>", "line": <line>, "side": "RIGHT", "body": "<finding text>" }
  ]
}
EOF
gh api --method POST repos/{owner}/{repo}/pulls/<number>/reviews --input review.json
```
