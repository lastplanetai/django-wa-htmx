#!/bin/bash
#
# create-pr.sh - Create GitHub PR for current changes and merge it
#
# Usage:
#   .martian/scripts/create-pr.sh "Title of the change"
#   .martian/scripts/create-pr.sh "Title" --quiet

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

QUIET=false
log() { $QUIET || echo -e "$@"; }

# Parse arguments
TITLE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --quiet|-q)
            QUIET=true
            shift
            ;;
        --help|-h)
            echo "Usage: create-pr.sh <title> [options]"
            echo ""
            echo "Options:"
            echo "  --quiet, -q  Suppress decorative output"
            echo "  --help, -h   Show this help"
            exit 0
            ;;
        -*)
            echo -e "${RED}Error: Unknown option $1${NC}"
            exit 1
            ;;
        *)
            if [ -z "$TITLE" ]; then
                TITLE="$1"
            else
                echo -e "${RED}Error: Unexpected argument: $1${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$TITLE" ]; then
    echo -e "${RED}Error: Title is required${NC}"
    echo "Usage: create-pr.sh <title>"
    exit 1
fi

for cmd in gh git; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: $cmd is not installed${NC}"
        exit 1
    fi
done

log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log "${BLUE}Creating PR: ${TITLE}${NC}"
log "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
log ""

# Step 1: Check for changes
log "Step 1: Checking for changes..."

if git diff --cached --quiet && git diff --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${YELLOW}Warning: No changes detected. Creating PR with existing commits.${NC}"
    HAS_CHANGES=false
else
    HAS_CHANGES=true
    log "${GREEN}✓ Changes detected${NC}"
fi

# Step 2: Linter + formatter
log ""
log "Step 2: Running linter + formatter check..."

log "  Checking linter..."
if ! poetry run ruff check . 2>&1; then
    echo -e "${RED}LINTER FAILED - PR BLOCKED${NC}"
    echo -e "${RED}Run: poetry run ruff check . --fix${NC}"
    exit 1
fi
log "${GREEN}  ✓ Linter passed${NC}"

log "  Checking formatting..."
if ! poetry run ruff format --check . 2>&1; then
    echo -e "${RED}FORMATTER FAILED - PR BLOCKED${NC}"
    echo -e "${RED}Run: poetry run ruff format .${NC}"
    exit 1
fi
log "${GREEN}  ✓ Formatting correct${NC}"

# Step 3: Run tests
log ""
log "Step 3: Running full test suite..."

if ! poetry run pytest 2>&1; then
    echo -e "${RED}TESTS FAILED - PR BLOCKED${NC}"
    exit 1
fi
log "${GREEN}  ✓ All tests passed${NC}"

log ""
log "${GREEN}✓ All checks passed${NC}"

# Step 4: Create branch
log ""
log "Step 4: Setting up branch..."

CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" = "main" ]; then
    BRANCH_SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-40 | sed 's/-$//')
    BRANCH_NAME="feature/${BRANCH_SLUG}"
    log "  Creating branch: $BRANCH_NAME"
    git checkout -b "$BRANCH_NAME"
else
    BRANCH_NAME="$CURRENT_BRANCH"
    log "  Using existing branch: ${YELLOW}$BRANCH_NAME${NC}"
fi

log "${GREEN}✓ On branch: ${BRANCH_NAME}${NC}"

# Step 5: Commit
log ""
log "Step 5: Committing changes..."

if [ "$HAS_CHANGES" = true ]; then
    git add -A
    COMMIT_MSG="${TITLE}

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
    git commit -m "$COMMIT_MSG"
    log "${GREEN}✓ Changes committed${NC}"
else
    log "${YELLOW}  No new changes to commit${NC}"
fi

# Step 6: Push
log ""
log "Step 6: Pushing to remote..."
git push -u origin "$BRANCH_NAME"
log "${GREEN}✓ Pushed to origin/${BRANCH_NAME}${NC}"

# Step 7: Create PR
log ""
log "Step 7: Creating Pull Request..."

PR_URL=$(gh pr create \
    --title "$TITLE" \
    --body "Generated with martian ensemble programming." \
    --base main \
    2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create PR${NC}"
    echo "$PR_URL"
    exit 3
fi

log "${GREEN}✓ PR created: ${PR_URL}${NC}"

# Step 8: Merge
log ""
log "Step 8: Merging PR (squash)..."

PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')

if gh pr merge "$PR_NUMBER" --squash --delete-branch 2>&1; then
    log "${GREEN}✓ PR merged and branch deleted${NC}"
    MERGED=true
else
    echo -e "${YELLOW}Warning: Could not auto-merge${NC}"
    MERGED=false
fi

# Summary
log ""
log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$MERGED" = true ]; then
    log "${GREEN}PR Created and Merged!${NC}"
else
    log "${GREEN}PR Created (awaiting merge)${NC}"
fi
log "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  PR:      ${PR_URL}"
echo "  Branch:  ${BRANCH_NAME}"
if [ "$MERGED" = true ]; then
    echo -e "  Status:  ${GREEN}Merged${NC}"
fi
echo ""
