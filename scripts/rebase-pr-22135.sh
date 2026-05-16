#!/bin/bash

##############################################################################
# Automated Rebase & Force-Push Script for PR #22135
# Purpose: Rebase Canmarha:master onto microsoft:master with conflict handling
# Usage: ./rebase-pr-22135.sh [REPO_PATH] [SKIP_FETCH] [DRY_RUN]
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Parameters
REPO_PATH="${1:-.}"
SKIP_FETCH="${2:-false}"
DRY_RUN="${3:-false}"

##############################################################################
# Helper Functions
##############################################################################

log_info() {
    echo -e "${CYAN}[$(date +'%H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_gray() {
    echo -e "${GRAY}   $1${NC}"
}

check_git() {
    if ! command -v git &> /dev/null; then
        log_error "Git not found in PATH"
        exit 1
    fi
}

check_working_dir() {
    if ! git -C "$REPO_PATH" diff-index --quiet HEAD -- 2>/dev/null; then
        log_error "Uncommitted changes detected in $REPO_PATH"
        exit 1
    fi
}

get_commit_count() {
    git -C "$REPO_PATH" log upstream/master..master --oneline 2>/dev/null | wc -l
}

show_separator() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

##############################################################################
# Main Script
##############################################################################

cd "$REPO_PATH" || exit 1

show_separator
log_info "  PR #22135 Automated Rebase Script"
show_separator

# Step 1: Validate environment
log_info "🔍 Step 1: Validating Environment"
check_git
log_success "   Git CLI found"

check_working_dir
log_success "   Working directory clean"

# Validate remotes
if ! git remote -v | grep -q "upstream"; then
    log_error "   'upstream' remote not configured"
    log_warn "   Run: git remote add upstream https://github.com/microsoft/azure-pipelines-tasks.git"
    exit 1
fi
log_success "   Remotes configured"

# Step 2: Fetch
if [ "$SKIP_FETCH" != "true" ]; then
    log_info "📡 Step 2: Fetching from Upstream"
    log_gray "Fetching microsoft:master..."
    
    if ! git fetch upstream master 2>&1 | grep -v "From github"; then
        log_error "   Fetch failed"
        exit 1
    fi
    log_success "   Fetch complete"
fi

# Step 3: Checkout master
log_info "🌳 Step 3: Checking Out Master"
if ! git checkout master > /dev/null 2>&1; then
    log_error "   Failed to checkout master"
    exit 1
fi
log_success "   Checked out master"

# Step 4: Show commits
log_info "📋 Step 4: Commits to Rebase"
COMMIT_COUNT=$(get_commit_count)

if [ "$COMMIT_COUNT" -eq 0 ]; then
    log_warn "   No commits to rebase (already up to date)"
    exit 0
fi

git log upstream/master..master --oneline | sed 's/^/   /'
log_warn "   Total: $COMMIT_COUNT commit(s)"

# Step 5: Confirm
if [ "$DRY_RUN" != "true" ]; then
    log_warn "Action Required"
    read -p "Continue with rebase? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "   Rebase cancelled by user"
        exit 1
    fi
fi

# Step 6: Rebase
log_info "🔄 Step 5: Rebasing onto upstream/master"
log_gray "Running: git rebase upstream/master"

if ! git rebase upstream/master; then
    log_error "REBASE CONFLICT DETECTED"
    
    log_warn "Conflicting Files:"
    git diff --name-only --diff-filter=U | sed 's/^/   ❌ /'
    
    echo ""
    log_info "🔧 Conflict Resolution Steps:"
    echo "   1. Open conflicting files above in your editor"
    echo "   2. Resolve conflicts manually (search for <<<<<<< and >>>>>>)"
    echo "   3. Run: git add ."
    echo "   4. Run: git rebase --continue"
    echo "   5. Re-run this script"
    echo ""
    echo "   Or abort rebase with: git rebase --abort"
    exit 1
fi

log_success "   Rebase successful - no conflicts!"

# Step 7: Force-push
log_info "📤 Step 6: Force-Pushing to Origin"
log_warn "   This will update your PR #22135 on GitHub"

if [ "$DRY_RUN" != "true" ]; then
    read -p "Force-push changes? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_error "   Push cancelled. Changes remain local."
        log_info "   To push manually later, run: git push origin master --force-with-lease"
        exit 0
    fi
fi

log_gray "Running: git push origin master --force-with-lease"
if ! git push origin master --force-with-lease; then
    log_error "   Force-push failed. Check authentication and permissions."
    exit 1
fi

log_success "   Force-push successful"

# Step 8: Summary
echo ""
show_separator
log_success "REBASE COMPLETE - PR IS NOW MERGEABLE!"
show_separator

echo ""
log_info "📊 What Happened:"
log_success "   Rebased $COMMIT_COUNT commit(s) onto upstream/master"
log_success "   No conflicts detected"
log_success "   Force-pushed to origin:master"

echo ""
log_info "📋 Next Steps:"
log_gray "1. GitHub re-evaluates PR status (~30 seconds)"
log_gray "2. Visit: https://github.com/microsoft/azure-pipelines-tasks/pull/22135"
log_gray "3. PR should now show as MERGEABLE ✅"
log_gray "4. Wait for maintainer review and approval"

echo ""
log_info "🔗 Resources:"
echo -e "${CYAN}   PR: https://github.com/microsoft/azure-pipelines-tasks/pull/22135${NC}"
echo -e "${CYAN}   Repo: https://github.com/microsoft/azure-pipelines-tasks${NC}"
echo ""
