#!/bin/bash
#
# start-pr.sh - Prepare workspace for a new PR
#
# 1. Verifies no uncommitted changes exist
# 2. Checks out main branch
# 3. Pulls latest changes from origin
#
# Usage: .martian/scripts/start-pr.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check for staged changes
echo "Checking for uncommitted changes..."

if ! git diff --cached --quiet; then
    echo -e "${RED}Error: You have staged changes.${NC}"
    echo ""
    echo "Staged files:"
    git diff --cached --name-only | sed 's/^/  /'
    echo ""
    echo "Options:"
    echo "  git commit -m 'message'  # Commit your changes"
    echo "  git stash                # Stash for later"
    echo "  git reset HEAD           # Unstage changes"
    exit 1
fi

# Check for unstaged changes
if ! git diff --quiet; then
    echo -e "${RED}Error: You have unstaged changes to tracked files.${NC}"
    echo ""
    echo "Modified files:"
    git diff --name-only | sed 's/^/  /'
    echo ""
    echo "Options:"
    echo "  git add . && git commit  # Commit your changes"
    echo "  git stash                # Stash for later"
    exit 1
fi

# Check for untracked files (warning only)
UNTRACKED=$(git ls-files --others --exclude-standard)
if [ -n "$UNTRACKED" ]; then
    echo -e "${YELLOW}Warning: Untracked files exist (not blocking):${NC}"
    echo "$UNTRACKED" | head -5 | sed 's/^/  /'
    UNTRACKED_COUNT=$(echo "$UNTRACKED" | wc -l | tr -d ' ')
    if [ "$UNTRACKED_COUNT" -gt 5 ]; then
        echo "  ... and $((UNTRACKED_COUNT - 5)) more"
    fi
    echo ""
fi

echo -e "${GREEN}✓ No uncommitted changes${NC}"

# Checkout main
echo ""
echo "Checking out main branch..."
if ! git checkout main 2>/dev/null; then
    echo -e "${RED}Error: Failed to checkout main branch${NC}"
    exit 2
fi
echo -e "${GREEN}✓ On main branch${NC}"

# Pull latest
echo ""
echo "Pulling latest changes from origin..."
if ! git pull origin main; then
    echo -e "${RED}Error: Failed to pull from origin/main${NC}"
    exit 2
fi
echo -e "${GREEN}✓ Main is up to date${NC}"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Ready to start new work!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
