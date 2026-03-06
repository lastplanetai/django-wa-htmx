#!/bin/bash
# resolve-venv.sh - Detect project venv and export VENV_BIN
#
# Source this from lifecycle scripts:
#   source "$(dirname "$0")/resolve-venv.sh"
#   $VENV_BIN/pytest
#   $VENV_BIN/ruff check .
#
# Detection order:
# 1. .venv/bin/ (standard venv)
# 2. Poetry venv via `poetry env info -p`
# 3. Empty — caller falls back to `poetry run`

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to project root so all tools resolve correctly
cd "$PROJECT_ROOT" || exit 1

VENV_BIN=""

# 1. Check .venv
if [ -x "$PROJECT_ROOT/.venv/bin/pytest" ]; then
    VENV_BIN="$PROJECT_ROOT/.venv/bin"
# 2. Check Poetry venv
elif [ -f "$PROJECT_ROOT/pyproject.toml" ]; then
    POETRY_VENV=$(poetry env info -p 2>/dev/null)
    if [ -n "$POETRY_VENV" ] && [ -d "$POETRY_VENV/bin" ]; then
        VENV_BIN="$POETRY_VENV/bin"
    fi
fi

export VENV_BIN
export PROJECT_ROOT
