# Handoff: hook `if` false-positive on brace expansion

Found while testing the `cg` plugin conversion (see `.claude-plugin/`), unrelated to that work — this bug already exists in this repo's hooks today. Not filed as a formal `rem-` ticket per the ticket workflow; that's the next step once someone picks this up.

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

## Who's affected in this repo right now

- `.claude/hooks/scan-commit-diff.sh` — scoped via `if: Bash(git commit:*)` / `if: Bash(git mv *)` variants in `.claude/settings.json` and its plugin mirror `.claude/hooks/hooks.json`
- `.claude/hooks/require-tests-before-review.sh` — scoped via `if: Bash(mv *)` and `if: Bash(git mv *)`

Any legitimate command with brace expansion — including ordinary scaffolding like the `init` skill's own `mkdir -p tickets/{features,remediation}/{todo,...}/` — currently risks a spurious block from either hook, unrelated to what the command actually does.

## Suggested fix (doesn't require Claude Code to fix the underlying matcher)

Make both scripts self-scoping: read `tool_input.command` (both scripts already do, via `jq` off stdin) and check it actually matches the intended trigger pattern *inside the script* before doing any real work, instead of trusting the dispatcher's `if` field alone as the only gate. If it doesn't match, `exit 0` immediately. This is a contained change to two files and removes the dependency on the buggy matcher entirely — worth doing regardless of whether/when upstream fixes the root cause.

## Suggested next step

Write this up as a proper `rem-N` ticket (`templates/ticket-remediation.md`) once someone's ready to pick it up, so it goes through the normal `/implement` TDD flow like any other fix.
