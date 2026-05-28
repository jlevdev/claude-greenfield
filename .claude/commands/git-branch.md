Create a new branch following project naming conventions.

## Naming conventions
| Branch type | Pattern | Example |
|-------------|---------|---------|
| Feature | `feat/<ticket-id>-<slug>` | `feat/feat-3-user-auth` |
| Bug fix | `fix/<ticket-id>-<slug>` | `fix/rem-2-login-crash` |
| Chore / refactor | `chore/<slug>` | `chore/upgrade-dependencies` |
| Release | `release/<version>` | `release/1.2.0` |
| Hotfix | `hotfix/<ticket-id>-<slug>` | `hotfix/rem-7-null-pointer` |

**Slug rules:** lowercase, hyphens only, max ~30 characters after the prefix.

## Steps
1. Identify the branch type from context (ticket ID, user description).
2. Generate the slug from the ticket title or user description — keep it concise.
3. Check if the branch already exists: `git branch --list <name>`
4. Create and switch: `git checkout -b <branch-name>`
5. Confirm the branch was created and show the full name.

## Note
If no base branch is specified, branch off the current branch. If working on a feature that should branch from `main` or `develop`, confirm with the user first.
