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
  # Any explicit remote name, not just origin/upstream -- `git push prod
  # main` is exactly as dangerous as `git push origin main`. The remote
  # token isn't anchored immediately after "push" so flags in between
  # (e.g. `git push -u prod main`) don't slip past this. Real bypass found
  # via the bypass-test suite (a "non-standard remote name" case already
  # existed and was failing), 2026-08-10.
  if echo "$COMMAND" | grep -qE '\bgit\s+push\b.*[^[:space:]]+\s+(main|master)\b'; then
    echo "Blocked: '$COMMAND' pushes directly to main/master. Per CLAUDE.md branch conventions, push a feat/fix/chore branch and open a PR instead." >&2
    exit 2
  fi
  # Destination-refspec syntax (src:dest), independent of remote name --
  # e.g. `git push origin HEAD:main`, `git push HEAD:master`, `git push
  # origin feature:main`. The check above only catches `origin main` /
  # `upstream main` as separate tokens; a refspec's destination is a
  # single `src:dest` token, so `origin HEAD:main` doesn't match it and
  # slipped through. Also catches `git push origin :main`, which deletes
  # the remote main branch outright. Real bypass found via code review,
  # confirmed against this hook, fixed here.
  if echo "$COMMAND" | grep -qE ':(main|master)\b'; then
    echo "Blocked: '$COMMAND' pushes to main/master via refspec destination syntax (src:dest). Push a feat/fix/chore branch and open a PR instead." >&2
    exit 2
  fi
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
