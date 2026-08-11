#!/bin/bash
# Blocks a short list of destructive, system-level Bash commands. Registered
# as a PreToolUse hook on the Bash matcher in .claude/settings.json.
# git/gh-specific guardrails live in git-safety.sh instead.
#
# Best-effort, not a sandbox: catches the common, obviously-dangerous
# shapes of these commands, not every possible obfuscation.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ -z "$COMMAND" ]] && exit 0

# 1. Recursive force-delete (rm -rf, rm -fr, rm -Rf, rm -r -f, rm --recursive
#    --force, in any flag order/case/spacing). Walked per-segment and
#    per-token rather than one regex, because a single pattern can't cover
#    "flags combined in one token" and "flags as separate tokens" and
#    "flags in either order" and "case-insensitive" all at once without
#    missing one of them -- found by bypass-testing the original regex.
while IFS= read -r segment; do
  echo "$segment" | grep -qE '\brm\b' || continue
  has_r=0; has_f=0
  for tok in $segment; do
    case "$tok" in
      --recursive) has_r=1 ;;
      --force) has_f=1 ;;
      -*)
        lower=$(echo "$tok" | tr '[:upper:]' '[:lower:]')
        [[ "$lower" == -*r* ]] && has_r=1
        [[ "$lower" == -*f* ]] && has_f=1
        ;;
    esac
  done
  if [[ "$has_r" -eq 1 && "$has_f" -eq 1 ]]; then
    echo "Blocked: '$COMMAND' looks like a recursive force-delete (rm -r and -f, combined or separate, any order/case) in '$segment'. If this is genuinely needed, ask the user to run it manually." >&2
    exit 2
  fi
done < <(echo "$COMMAND" | tr ';&|' '\n')

# 2. Fork bombs (classic ":(){ :|:& };:" and close variants)
if echo "$COMMAND" | grep -qE ':\s*\(\s*\)\s*\{[^}]*\|[^}]*&[^}]*\}\s*;\s*:'; then
  echo "Blocked: '$COMMAND' looks like a fork bomb." >&2
  exit 2
fi

# 3. Writing raw bytes to a block device, or formatting one (dd/mkfs)
if echo "$COMMAND" | grep -qE '\bdd\s+[^|;&]*of=/dev/(sd|nvme|hd|disk|xvd)'; then
  echo "Blocked: '$COMMAND' writes directly to a block device." >&2
  exit 2
fi
if echo "$COMMAND" | grep -qE '\bmkfs(\.[a-zA-Z0-9]+)?\s+.*\s*/dev/'; then
  echo "Blocked: '$COMMAND' formats a block device." >&2
  exit 2
fi

# 4. Recursively opening up permissions on root/home. Checked as
#    "-R/--recursive and 777 both present, target is root/home", not
#    "-R immediately precedes 777" -- the latter missed `chmod 777 -R /`
#    (flags after the mode).
if echo "$COMMAND" | grep -qE '\bchmod\b' \
  && echo "$COMMAND" | grep -qE -- '(-R\b|--recursive\b)' \
  && echo "$COMMAND" | grep -qE '\b0?777\b' \
  && echo "$COMMAND" | grep -qE '([[:space:]]|^)(/|\$HOME|~)([[:space:]]|$)'; then
  echo "Blocked: '$COMMAND' recursively makes root/home world-writable." >&2
  exit 2
fi

# 5. Piping a remote download straight into a shell (supply-chain risk)
if echo "$COMMAND" | grep -qE '(curl|wget)[^|]*\|\s*(sudo\s+)?(sh|bash|zsh)\b'; then
  echo "Blocked: '$COMMAND' pipes a remote download directly into a shell. Download it, read it, then run it — per this project's package-vetting research standards." >&2
  exit 2
fi

# 6. Piping a base64-decoded (or similarly decoded) payload straight into a
#    shell -- the same risk as #5, just obfuscated past a literal-text
#    scan. Added after bypass-testing #5 found it didn't cover this
#    encoding.
if echo "$COMMAND" | grep -qEi '(base64|openssl\s+(enc|base64))[^|;&]*(-d\b|--decode\b)[^|;&]*\|\s*(sudo\s+)?(sh|bash|zsh)\b'; then
  echo "Blocked: '$COMMAND' pipes a decoded payload directly into a shell. Decode it, read it, then run it." >&2
  exit 2
fi

exit 0
