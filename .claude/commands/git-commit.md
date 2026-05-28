Stage and commit changes using a conventional commit message.

## Conventional commit format
`<type>(<scope>): <short description>`

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `ci`
**Scope:** the area of the codebase affected (e.g., `auth`, `map`, `api`, `ui`)
**Description:** imperative mood, under 72 characters, no period at the end

Examples:
- `feat(auth): add JWT refresh token flow [feat-3]`
- `fix(map): correct off-by-one in zoom level calculation [rem-2]`
- `test(travel): add edge cases for zero-distance journeys`

## Steps
1. Run `git status` and `git diff` to understand what changed.
2. If the user did not specify which files to stage, ask — or confirm "everything" if they say so.
3. Identify the commit type from context.
4. Reference ticket IDs in the message when applicable (append `[feat-N]` or `[rem-N]`).
5. Add a commit body if the change needs more context beyond the subject line.
6. Stage the specified files and commit. Never use `--no-verify`.

## Safety checks
- Never stage `.env` files, secrets, credentials, or large binaries.
- If unrelated changes are mixed in, flag them and ask whether to split into multiple commits.
- Warn if the diff is unexpectedly large for the stated ticket scope.
