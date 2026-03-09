#!/bin/sh
set -eu

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

cd "$REPO_ROOT"
chmod +x .githooks/pre-commit .githooks/commit-msg
git config core.hooksPath .githooks

echo "Git hooks installed from $REPO_ROOT/.githooks"
