# Handoff: hook `if` false-positive on brace expansion

Found while testing the `cg` plugin conversion (see `.claude-plugin/`), unrelated to that work. Originally written up here to be handled as a separate follow-up after pushing the plugin changes — but CodeRabbit's review of the resulting PR (#10) independently surfaced the same bug against `.claude/hooks/hooks.json`, and the repo-local instances were fixed in that same PR rather than deferred. This file is kept as the record of the underlying issue, which is still real: the fix below works around it locally, it doesn't change the platform's `if` matcher itself.

## The bug

A hook entry scoped with an `"if"` permission-rule pattern (e.g. `"if": "Bash(git commit:*)"`) fires on **any** Bash command containing curly-brace syntax — `mkdir -p a/{b,c}`, `cp f.{txt,bak}`, etc. — regardless of whether the command actually matches the pattern. A command without braces is correctly filtered; one with braces always triggers the hook, every time.

Confirmed this is a Claude Code core bug (the `if` permission-rule matcher itself), not specific to this repo's setup or to plugin-sourced hooks: reproduced identically with a minimal, single-hook `.claude/settings.json` containing nothing else, no plugin involved.

Filed as product feedback via `SendFeedback` in the session that found it (queued locally in that session, not necessarily sent — check `/feedback` history if you want to confirm/send it).

## Repro

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "if": "Bash(git commit:*)", "command": "echo BLOCKED >&2; exit 2" }
        ]
      }
    ]
  }
}
```
Drop that in `.claude/settings.json` in an empty scratch dir, ask Claude Code to run `mkdir -p x/{a,b}` — it gets blocked, even though the command has nothing to do with `git commit`.

## Who was affected in this repo, and what changed

- `.claude/hooks/scan-commit-diff.sh` — was scoped via `if: Bash(git commit:*)` in `.claude/settings.json` and its plugin mirror `.claude/hooks/hooks.json`. **Fixed**: now reads `tool_input.command` and self-checks for `\bgit[[:space:]]+commit\b` before doing any real work, exiting 0 immediately otherwise. The dispatcher-only `if` field was removed from both `settings.json` and `hooks.json` — it added nothing once the script self-scopes, and kept implying a scoping guarantee it couldn't actually provide.
- `.claude/hooks/require-tests-before-review.sh` — was scoped via `if: Bash(mv *)` and `if: Bash(git mv *)`. Turned out this one **already self-scoped** (it checks the command for a `tickets/(features|remediation)/review/` path before doing anything), so it was never actually vulnerable — a spuriously-triggered invocation already exited 0 safely. Its now-redundant `if` fields were removed too, for consistency and to stop implying the dispatcher was doing the scoping.

Both fixes verified directly: piping a synthetic `mkdir -p a/{b,c}` `tool_input.command` at `scan-commit-diff.sh` now exits 0 immediately, while a real `git commit -m "..."` command still flows through to the actual scan logic.

**Not touched, still exposed**: the `PostToolUse` hooks scoped via `if: Bash(gh pr view:*)` / `Bash(gh pr diff:*)` / `Bash(gh api:*)` (all three route to `scan-fetched-content-for-injection.sh`) rely on the same buggy `if` matcher and weren't in scope of the review thread that prompted this fix. `scan-fetched-content-for-injection.sh` does not currently self-check its trigger condition. Same fix shape applies whenever this gets picked up.

## Suggested next step

Write up the remaining `PostToolUse`/`gh`-scoped gap as a proper `rem-N` ticket (`templates/ticket-remediation.md`) so it goes through the normal `/implement` TDD flow.
