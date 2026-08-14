#!/bin/bash
# Scans the staged diff for known-dangerous code patterns before allowing a
# `git commit` to proceed. Registered as a PreToolUse hook on the Bash
# matcher, scoped via the "if" field in .claude/settings.json to
# `Bash(git commit:*)`. Pattern list lives in lib/dangerous-code-patterns.txt.
#
# This is the deterministic first layer only -- pattern matching, not a
# multi-file data-flow trace (that requires actual reasoning, not grep, so
# it can't live in a hook the way this can). When this hook blocks, the
# message asks Claude to reason about the flagged lines itself -- call
# sites, trust boundaries, whether the match is exploitable -- before
# retrying the commit. That keeps the judgment call with the model, where it
# belongs, while still guaranteeing the check actually happens rather than
# depending on the model to remember to look.
#
# Note this hook only ever inspects the diff, never the commit message --
# there is no "explain the false positive and retry" path, because nothing
# about retrying changes what gets scanned. A genuine false positive is
# handled via the exemption list below, not by wording the commit
# differently.
#
# Best-effort, not a scanner: only lines *added* by this diff are checked (a
# line being removed or untouched context isn't this commit's problem), and
# a multi-line statement can slip past a single-line regex.
#
# Fail closed, not open: an environment failure here (can't resolve the
# project dir, pattern file missing, git itself errors) must not look
# identical to "nothing to scan" -- that's the same bug git-safety.sh's
# bare-push fix exists to prevent (see its comment on "Fail closed, not
# open"), and this hook had it in three places until this fix.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATTERNS_FILE="$SCRIPT_DIR/lib/dangerous-code-patterns.txt"

if ! cd "$CLAUDE_PROJECT_DIR" 2>/dev/null; then
  echo "Blocked: can't verify this commit is safe -- couldn't resolve the project directory (\$CLAUDE_PROJECT_DIR='$CLAUDE_PROJECT_DIR'). Refusing to allow an unscanned commit; resolve the error and retry." >&2
  exit 2
fi

if [[ ! -f "$PATTERNS_FILE" ]]; then
  echo "Blocked: can't verify this commit is safe -- the dangerous-code pattern file is missing (expected at '$PATTERNS_FILE'). Refusing to allow an unscanned commit; restore the file and retry." >&2
  exit 2
fi

# Files whose entire purpose is to contain these patterns as text, not as
# live code: the pattern-definition list itself, and this hook's own
# bypass-test fixtures, which deliberately stage strings like
# 'eval(user_input)' to prove the scanner catches them. Without this
# exemption, any commit touching either file would be permanently blocked,
# with no way to satisfy the hook -- it re-scans the diff every retry
# regardless of the commit message.
_is_exempt_file() {
  case "$1" in
    .claude/hooks/lib/dangerous-code-patterns.txt) return 0 ;;
    # Narrowly scoped to the one fixture that legitimately needs to
    # contain literal dangerous-looking strings -- not the whole tests/
    # directory, so a real dangerous pattern added to any other file
    # under tests/ still gets scanned. Narrowed from a directory-wide
    # exemption after independent agreement from silent-failure-hunter
    # and CodeRabbit's review of PR #3, 2026-08-13.
    .claude/hooks/tests/bypass-test.sh) return 0 ;;
    *) return 1 ;;
  esac
}

# `git commit -a`/`--all` auto-stages modifications to already-tracked
# files as part of the commit itself -- at PreToolUse time, before `git
# commit` has actually run, those changes are sitting unstaged, not in
# `git diff --cached`. Scan against HEAD (staged + unstaged) instead
# whenever -a is present, so what's about to actually be committed is what
# gets checked, not just what happens to already be staged.
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
DIFF_REF="--cached"
if echo "$COMMAND" | grep -qE -- '(^|[[:space:]])-a[a-zA-Z]*([[:space:]]|$)|--all\b'; then
  DIFF_REF="HEAD"
fi

# `git commit <pathspec>` (e.g. `git commit f.py`) has the same effect as
# -a but scoped to that path: it includes the path's unstaged tracked
# content even though it was never staged. Reliably telling a pathspec
# apart from other commit arguments needs a real parser, not a regex --
# this is a best-effort heuristic, not that parser: strip a simple -m/
# --message value (a plain "..."/'...'/$(...) argument) and known no-
# value flags, and if anything is left over, treat it as a possible
# pathspec and broaden to HEAD, same as -a. Errs toward over-scanning
# (safe) on anything it can't confidently strip, rather than trying
# harder to prove a pathspec is absent. Skipped entirely for a heredoc
# message (`-m "$(cat <<'EOF' ... EOF)"`, this project's own git-commit
# convention) -- the message body can contain almost anything, including
# text that would trip the stripping regex, and a heredoc is never
# itself a pathspec. Real gap found via the pr-review skill (CodeRabbit's
# review of PR #3), 2026-08-13.
if [[ "$DIFF_REF" == "--cached" ]] && ! echo "$COMMAND" | grep -qE -- '(-m|--message)[[:space:]]*.*<<'; then
  STRIPPED=$(echo "$COMMAND" | sed -E '
    s/^.*\bgit[[:space:]]+commit\b//;
    s/(-m|--message)[[:space:]]+"[^"]*"//g;
    s/(-m|--message)[[:space:]]+'"'"'[^'"'"']*'"'"'//g;
    s/(-m|--message)[[:space:]]+\$\([^)]*\)//g;
    s/(-m|--message)[[:space:]]+[^[:space:]"'"'"'$]+//g;
    s/(^|[[:space:]])--?(a|all|amend|no-edit|no-verify|verbose|v|quiet|q|signoff|s|edit|e)\b//g;
  ')
  if echo "$STRIPPED" | grep -qE '[^[:space:]]'; then
    DIFF_REF="HEAD"
  fi
fi

CHANGED_FILES=$(git diff "$DIFF_REF" --name-only 2>&1)
GIT_RC=$?
if [[ "$GIT_RC" -ne 0 ]]; then
  echo "Blocked: can't verify this commit is safe -- 'git diff $DIFF_REF --name-only' failed (git said: $CHANGED_FILES). Refusing to allow an unscanned commit; resolve the git error and retry." >&2
  exit 2
fi
[[ -z "$CHANGED_FILES" ]] && exit 0

FINDINGS=""
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  _is_exempt_file "$file" && continue

  # Lines this file's diff adds, stripped of the leading '+'. The [^+]
  # excludes '+++ b/path' file-header lines, which also start with '+'.
  ADDED_LINES=$(git diff "$DIFF_REF" -- "$file" 2>/dev/null | grep -E '^\+[^+]' | sed 's/^+//')
  [[ -z "$ADDED_LINES" ]] && continue

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    pattern="${line%%:::*}"
    reason="${line#*:::}"
    pattern="$(echo "$pattern" | sed 's/[[:space:]]*$//')"
    reason="$(echo "$reason" | sed 's/^[[:space:]]*//')"
    [[ -z "$pattern" ]] && continue

    MATCHES=$(echo "$ADDED_LINES" | grep -nE -- "$pattern")
    if [[ -n "$MATCHES" ]]; then
      FINDINGS+=$'\n'"  - $file: pattern '$pattern' ($reason):"$'\n'
      FINDINGS+="$(echo "$MATCHES" | sed 's/^/      /')"$'\n'
    fi
  done < "$PATTERNS_FILE"
done <<< "$CHANGED_FILES"

[[ -z "$FINDINGS" ]] && exit 0

{
  echo "Blocked: the staged diff for this commit matches known-dangerous code patterns:"
  echo "$FINDINGS"
  echo "Before retrying the commit: read the flagged lines in context, trace where the data comes from and where it goes, and decide whether this is genuinely exploitable (injection, IDOR, auth bypass, SSRF, hardcoded secret, etc.). Fix real issues, then retry. If this is a genuine false positive in a file that isn't already exempt, add it to _is_exempt_file() in scan-commit-diff.sh -- rewording the commit message will not change the outcome, since this hook only inspects the diff."
} >&2
exit 2
