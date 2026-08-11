#!/bin/bash
# Runs bypass-test.sh inside an isolated, network-less Docker container.
#
# Why: every hook here only inspects the JSON it's handed except one --
# require-tests-before-review.sh, which does `eval "$TEST_CMD"` for real.
# The test suite shims a fake `npm` onto PATH so that eval never reaches a
# real toolchain (see tests/bypass-test.sh), but running the whole suite
# with --network none and a read-only repo mount means even a wrong test
# case, or a future hook that isn't as careful, can't reach the network or
# write outside the container. This is the same script both local runs and
# the hook-tests CI workflow use, so there's one code path to trust.
#
# Usage: .claude/hooks/tests/run-sandboxed.sh
# Requires: Docker.

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$HOOKS_DIR/../.." && pwd)"
IMAGE="claude-hooks-bypass-test-sandbox"

docker build -q -t "$IMAGE" -f "$HOOKS_DIR/tests/Dockerfile.sandbox" "$HOOKS_DIR/tests" >/dev/null

docker run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp:exec \
  -v "$REPO_ROOT":/repo:ro \
  -w /repo \
  -e CLAUDE_PROJECT_DIR=/repo \
  "$IMAGE" \
  bash ./.claude/hooks/tests/bypass-test.sh
