Open a pull request on GitHub for the current branch using the `gh` CLI.

## Default platform: GitHub
This project uses GitHub. Use `gh` for all PR operations. If a specific project overrides this in its `CLAUDE.md` Tech Stack table to GitLab, use `glab mr create` instead.

## Create a PR
```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

## PR body template
```
## What
- <change 1>
- <change 2>

## Why
<motivation — reference ticket IDs>

## Test plan
- [ ] All existing tests pass
- [ ] <specific verification step>
- [ ] <another step>

## Tickets
Closes: feat-N, rem-N
```

## Steps
1. Run `git log <base-branch>..HEAD --oneline` to understand what's in this branch.
2. Read the ticket files referenced in commit messages for context.
3. Draft the title (under 70 chars) and body using the template above.
4. Confirm the draft with the user before creating.
5. Create the PR and return the URL.

## Notes
- Ensure `gh auth login` has been run before first use.
- For GitHub Enterprise: `gh` works the same way; run `gh auth login --hostname <your-host>`.
- For a project that uses GitLab instead: use `glab mr create --title "<title>" --description "<body>"`. Ensure `glab` is installed and `glab auth login` has been run.
