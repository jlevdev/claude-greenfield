#!/bin/bash
# Blocks force-pushes, direct pushes to main/master, and the highest-blast-
# radius destructive `gh` CLI operations. Registered as a PreToolUse hook on
# the Bash matcher in .claude/settings.json. System-level guardrails (rm -rf,
# fork bombs, etc.) live in block-dangerous-commands.sh instead.
#
# Best-effort, not a sandbox: this is meant to stop an agent from doing
# these things on its own initiative, not to defeat a determined bypass.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ -z "$COMMAND" ]] && exit 0

if echo "$COMMAND" | grep -qE '\bgit\s+push\b'; then
  if echo "$COMMAND" | grep -qE -- '(--force\b|--force-with-lease\b|\s-f\b)'; then
    echo "Blocked: '$COMMAND' force-pushes. Force-push is a human-only action in this project." >&2
    exit 2
  fi
  # --all and --mirror push every local branch (--mirror: every ref) to
  # the remote, including main/master, and match neither the
  # explicit-branch check below (no branch name token to match) nor the
  # bare-push fallback (skipped whenever the remote has any argument,
  # which --all/--mirror count as). Real bypass found via the pr-review
  # skill (CodeRabbit's review of PR #3), 2026-08-13.
  if echo "$COMMAND" | grep -qE -- '\bgit\s+push\b.*(--all\b|--mirror\b)'; then
    echo "Blocked: '$COMMAND' pushes all branches/refs, which includes main/master regardless of remote. Push a single feat/fix/chore branch instead." >&2
    exit 2
  fi
  # Isolate each `git push ...` invocation's own segment, stopping at the
  # next shell delimiter (;, &, |, #) -- otherwise a `main`/`master`
  # mention in a later, unrelated chained command (e.g. `gh pr create
  # --base main` after `&&`) gets mistaken for part of this push. Real
  # false-block found via the pr-review skill, 2026-08-11: `git push
  # origin feat/x && gh pr create --base main --head feat/x` (git-ship's
  # own documented flow) was blocked even though the push itself never
  # touches main.
  #
  # Naive delimiter-splitting doesn't know that a ; or & *inside a
  # quoted string* isn't a real command delimiter -- `git push origin
  # 'feature;safe:main'` would otherwise truncate the segment before the
  # real ':main' destination, missing it entirely (real bypass found via
  # the pr-review skill, CodeRabbit's review of PR #3, 2026-08-13). A
  # first fix disabled splitting outright whenever any quote character
  # appeared anywhere in the command -- but that's most commands: an
  # ordinary apostrophe in unrelated prose (a commit message discussing
  # this very fix, for instance) triggered it too, reopening the
  # compound-command false-block on nearly everything. Mask delimiter
  # characters that fall *inside* a quoted region instead, so splitting
  # stays precise rather than being disabled wholesale. Quote characters
  # themselves are left alone (the boundary check below still needs to
  # see them), only ; & | # get masked, and only while inside a quote.
  MASKED_COMMAND=$(echo "$COMMAND" | awk '
    {
      n = length($0); instr = 0; qc = ""; out = ""
      for (i = 1; i <= n; i++) {
        c = substr($0, i, 1)
        if (instr) {
          if (c == qc) { instr = 0 }
          else if (c == ";" || c == "&" || c == "|" || c == "#") { c = "_" }
        } else if (c == "\x27" || c == "\"") {
          instr = 1; qc = c
        }
        out = out c
      }
      print out
    }')
  PUSH_SEGMENTS=$(echo "$MASKED_COMMAND" | grep -oE '\bgit[[:space:]]+push\b[^;&|#]*')

  while IFS= read -r segment; do
    [[ -z "$segment" ]] && continue

    # Any explicit remote name, not just origin/upstream -- `git push prod
    # main` is exactly as dangerous as `git push origin main`. Matches
    # main/master as a bare token (`origin main`) or as the final
    # component of a `refs/heads/...` path (`prod refs/heads/main`) --
    # the bare-token-only form missed full-ref-path pushes, a real bypass
    # found via the pr-review skill (CodeRabbit's review of PR #3),
    # 2026-08-11. Deliberately scoped to the literal `refs/heads/` prefix
    # rather than any prefix ending in `/`, so a differently-named branch
    # that merely ends in "/main" (e.g. `release/main`) isn't blocked.
    # The trailing boundary also accepts a quote character, not just
    # whitespace/end-of-string -- needed for the quoted-command fallback
    # above, where `main` is followed by a closing quote rather than a
    # space (e.g. `origin 'feature;safe:main'`).
    if echo "$segment" | grep -qE "[^[:space:]]+[[:space:]]+(refs/heads/)?(main|master)([[:space:]\"']|\$)"; then
      echo "Blocked: '$COMMAND' pushes directly to main/master. Per CLAUDE.md branch conventions, push a feat/fix/chore branch and open a PR instead." >&2
      exit 2
    fi
    # Destination-refspec syntax (src:dest), independent of remote name --
    # e.g. `git push origin HEAD:main`, `git push HEAD:master`, `git push
    # origin feature:main`, `git push origin :main` (deletes remote main
    # outright), and full-ref-path destinations like
    # `HEAD:refs/heads/main`. Same quote-tolerant boundary as above.
    if echo "$segment" | grep -qE ":(refs/heads/)?(main|master)([[:space:]\"']|\$)"; then
      echo "Blocked: '$COMMAND' pushes to main/master via refspec destination syntax (src:dest). Push a feat/fix/chore branch and open a PR instead." >&2
      exit 2
    fi
  done <<< "$PUSH_SEGMENTS"
  # Bare `git push` / `git push origin` pushes whatever the current branch
  # tracks — only a problem if that happens to be main/master.
  if ! echo "$COMMAND" | grep -qE '\b(origin|upstream)\s+\S+'; then
    CURRENT_BRANCH=$(git -C "$CLAUDE_PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>&1)
    GIT_RC=$?
    if [[ "$GIT_RC" -ne 0 ]]; then
      # Fail closed, not open: this branch used to swallow the error
      # (2>/dev/null) and let an unresolvable branch name fall through as
      # "not main/master", silently allowing a bare push through. Found via
      # containerized testing (git refuses to operate on a repo owned by a
      # different UID -- "dubious ownership" -- which is exactly a
      # can't-determine-the-branch case, not a rare one). If we can't tell
      # what branch this pushes, don't assume it's safe.
      echo "Blocked: '$COMMAND' is a bare push and the current branch couldn't be determined (git said: $CURRENT_BRANCH), so this can't be confirmed safe. Resolve the git error and retry, or ask the user to run it manually." >&2
      exit 2
    fi
    if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
      echo "Blocked: '$COMMAND' would push the current branch ('$CURRENT_BRANCH') directly. Branch first, per CLAUDE.md conventions." >&2
      exit 2
    fi
  fi
fi

# Force-deleting a local main/master branch
if echo "$COMMAND" | grep -qE '\bgit\s+branch\s+(-D|--delete\s+--force)\s+(main|master)\b'; then
  echo "Blocked: '$COMMAND' force-deletes the main/master branch." >&2
  exit 2
fi

# Highest-blast-radius destructive gh CLI operations
if echo "$COMMAND" | grep -qE '\bgh\s+repo\s+delete\b'; then
  echo "Blocked: '$COMMAND' deletes a GitHub repository. This is a human-only action." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '\bgh\s+release\s+delete\b'; then
  echo "Blocked: '$COMMAND' deletes a GitHub release. Ask the user to confirm and run it themselves." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '\bgh\s+api\s+.*(-X|--method)\s+DELETE\b'; then
  echo "Blocked: '$COMMAND' issues a raw DELETE against the GitHub API. Ask the user to confirm and run it themselves." >&2
  exit 2
fi

exit 0
