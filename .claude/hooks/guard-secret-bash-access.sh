#!/bin/bash
# Blocks Bash commands that read, copy, or otherwise move a protected file
# (secrets, lockfiles, credential files -- see lib/protected-patterns.txt)
# even though neither the Read nor Write/Edit tool was used. Registered as
# a PreToolUse hook on the Bash matcher in .claude/settings.json.
#
# Why this exists: guard-secret-reads.sh blocks `Read` on .env; protect-
# files.sh blocks `Edit`/`Write` on .env. Neither stops `cat .env` or
# `cp .env /tmp/x` run via Bash -- same information, a different tool. That
# gap is the main reason this file exists.
#
# Heuristic, not a parser: tokenizes on whitespace, so quoting tricks and
# non-literal paths (variables, command substitution, symlinks with an
# unrelated name) can still get through -- see the "known gap" cases in
# tests/bypass-test.sh for what's intentionally not covered yet.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/check-protected-path.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[[ -z "$COMMAND" ]] && exit 0

# Only look closer at commands that are actually capable of surfacing or
# moving file *content* (as opposed to `test -f .env`, `stat .env`, `ls`,
# which touch metadata only and are common/harmless). Keeps this hook from
# firing on every unrelated mention of a protected filename.
EXFIL_CAPABLE='\b(cat|less|more|head|tail|grep|egrep|fgrep|awk|sed|cp|mv|scp|rsync|tar|zip|gzip|base64|xxd|od|strings|nc|ncat|curl|wget|python[0-9.]*|node|ruby|perl|vi|vim|nano|emacs|cut|tee|xargs|source)\b'

echo "$COMMAND" | grep -qEi "$EXFIL_CAPABLE" || exit 0

for token in $COMMAND; do
  # Strip common surrounding quote/punctuation characters so '.env', ".env",
  # and .env, all resolve to the same check.
  clean=$(echo "$token" | sed -E "s/^['\"]+//; s/['\",;]+\$//")
  [[ -z "$clean" ]] && continue

  if MATCHED_PATTERN=$(check_protected_path "$clean"); then
    echo "Blocked: '$COMMAND' looks like it reads or moves '$clean' via Bash, which matches protected pattern '$MATCHED_PATTERN'. This is the same protection guard-secret-reads.sh applies to the Read tool, extended to cover Bash. If you need a specific value from this file, ask the user to share just that value." >&2
    exit 2
  fi
done

exit 0
