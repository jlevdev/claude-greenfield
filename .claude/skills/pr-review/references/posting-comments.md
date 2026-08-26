# Posting PR comments (pr-review)

Exact command shape for Step 7's `Post as PR comment` action. Read this when findings are actually about to be posted, not before.

Draft the comment text for all selected findings, show the draft, then post.

`gh pr comment`/`gh pr review --comment` only post general, top-level comments — neither has a flag for a line-anchored inline comment (verified: no `gh` CLI option exists for this). That's fine for a finding with no specific `file:line` to anchor to.

For findings anchored to a specific `file:line`, batch them into **one** `gh api repos/{owner}/{repo}/pulls/<number>/reviews` call instead, with a `comments` array of `{path, line, side, body}` objects — one API call posting all of them as a single review, not one call per finding.
