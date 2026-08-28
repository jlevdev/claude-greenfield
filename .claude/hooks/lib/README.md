# Injection-pattern store: two tiers

`scan-fetched-content-for-injection.sh` checks fetched content against two
merged pattern lists — deliberately kept in different places because they
have different lifecycles.

| | Core tier | Shared tier |
|---|---|---|
| Location | `injection-patterns.txt` (this directory) | `~/.claude/shared/injection-patterns.txt` |
| Lives in | This repo, checked in | This machine, outside any repo |
| Reviewed via | git history / PR | Nothing — append-only, no review gate |
| Tested by | `.claude/hooks/tests/bypass-test.sh`, sandboxed in CI | Not run in CI at all (see below) |
| Reaches | Only *new* checkouts/clones of this template, after a merge | *Every* project on this machine using this hook, on its very next run |

## Why two tiers

This repo is a template — it gets copied into multiple separate project
repos on the same developer machine over time. A phrase caught in one
project's live session (e.g. `pr-watch` flags a new bypass attempt in a
real PR review) is only useful to the *other* active projects if it
propagates without a template-sync round trip. The shared tier is that
propagation path: any project's hook run can append to it, and every other
project's hook run picks it up immediately, because they all resolve the
same `~/.claude/shared/injection-patterns.txt` path by default.

The core tier stays the reviewed, permanent record — the shape you want a
freshly-instantiated project to start with on day one, with a real test
case behind each entry.

## Adding a pattern

**Found something live (a real catch, not a hypothetical):** append it to
the shared tier. Comment each addition with the date and a one-line source
("2026-08-28, PR #N of project X: ...") — the shared file has no git
history, so that comment is the only provenance it'll ever have.

**Confident it's a durable, general pattern, not a one-off:** add it to the
core tier instead (or promote it there later — see below), with a
bypass-test.sh case (see the `check_flagged` cases already in that file
for the shape).

## Promotion path

The shared tier is meant to be a *staging* area, not a permanent home for
everything. Periodically (there's no automated trigger for this — it's a
manual housekeeping pass), review `~/.claude/shared/injection-patterns.txt`
for entries that have proven their worth, and PR them into the core file
here with a corresponding `bypass-test.sh` case. That's how a pattern goes
from "this machine only" to "every future clone of this template starts
protected by it."

## Why the shared tier isn't in CI

`bypass-test.sh`'s sandboxed run (`tests/run-sandboxed.sh`) only mounts
this repo — it has no access to `~/.claude/shared/` inside the container,
and that's intentional, not a gap: CI needs to be reproducible from repo
state alone. The shared tier is deliberately extra-repo, so it's out of
CI's reach by construction. Anything you want CI-verified belongs in the
core tier.

## `$HOME` caveat

The hook resolves the shared-tier path via `$HOME`, which Claude Code does
not guarantee is set in a hook's environment (see the [hooks
reference](https://code.claude.com/docs/en/hooks#environment-variables) —
only `CLAUDE_PROJECT_DIR` is documented as guaranteed). If `$HOME` is
unset, or the file just doesn't exist yet on a given machine, the hook
silently falls back to core-tier-only — same as any other missing-file
case in this hook, never a hard failure. Override the resolved path with
`CLAUDE_SHARED_PATTERNS_FILE` if you need something other than
`~/.claude/shared/injection-patterns.txt`.
