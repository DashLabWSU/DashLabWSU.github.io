#!/bin/bash
set -euo pipefail

# -----------------------------
# EDIT THESE PATHS/BRANCHES
# -----------------------------
SOURCE_DIR="$HOME/Documents/Coding/DASHWebsite"
DEPLOY_DIR="$HOME/Documents/Coding/DashLabWSU.github.io"
SOURCE_BRANCH="main"
DEPLOY_BRANCH="main"
SOURCE_REMOTE="origin"
DEPLOY_REMOTE="origin"

# Optional commit message passed in as first argument
MESSAGE="${1:-Site update $(date '+%Y-%m-%d %H:%M:%S')}"

commit_if_needed() {
  local repo_dir="$1"
  local message="$2"
  local label="$3"

  cd "$repo_dir"
  git add -A

  if ! git diff --cached --quiet; then
    git commit -m "$message"
  else
    echo "No $label changes to commit."
  fi
}

sync_branch() {
  local repo_dir="$1"
  local remote_name="$2"
  local branch_name="$3"
  local label="$4"

  cd "$repo_dir"

  if ! git remote get-url "$remote_name" >/dev/null 2>&1; then
    echo "Error: Missing remote '$remote_name' for $label repo."
    exit 1
  fi

  if git ls-remote --exit-code --heads "$remote_name" "$branch_name" >/dev/null 2>&1; then
    git pull --rebase "$remote_name" "$branch_name"
  else
    echo "Remote branch '$remote_name/$branch_name' does not exist yet for $label repo."
    echo "The next push will create it."
  fi
}

# -----------------------------
# CHECKS
# -----------------------------
for cmd in git bundle rsync; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is not installed or not in PATH."
    exit 1
  fi
done

if [ ! -d "$SOURCE_DIR/.git" ]; then
  echo "Error: SOURCE_DIR is not a git repo: $SOURCE_DIR"
  exit 1
fi

if [ ! -d "$DEPLOY_DIR/.git" ]; then
  echo "Error: DEPLOY_DIR is not a git repo: $DEPLOY_DIR"
  exit 1
fi

if [ ! -f "$SOURCE_DIR/Gemfile" ]; then
  echo "Error: No Gemfile found in source repo."
  exit 1
fi

# -----------------------------
# 1) COMMIT + PUSH SOURCE REPO
# -----------------------------
echo "==> Updating source repo..."
cd "$SOURCE_DIR"
commit_if_needed "$SOURCE_DIR" "$MESSAGE" "source"
sync_branch "$SOURCE_DIR" "$SOURCE_REMOTE" "$SOURCE_BRANCH" "source"
git push -u "$SOURCE_REMOTE" "$SOURCE_BRANCH"

# -----------------------------
# 2) BUILD JEKYLL SITE
# -----------------------------
echo "==> Building Jekyll site..."
JEKYLL_ENV=production bundle exec jekyll build

# Prevent GitHub Pages from trying to rebuild the prebuilt output
touch "$SOURCE_DIR/_site/.nojekyll"

# -----------------------------
# 3) COPY OUTPUT TO DEPLOY REPO
# -----------------------------
echo "==> Syncing built site to deploy repo..."
rsync -av --delete \
  --exclude=".git" \
  "$SOURCE_DIR/_site/" "$DEPLOY_DIR/"

# -----------------------------
# 4) COMMIT + PUSH DEPLOY REPO
# -----------------------------
echo "==> Updating deploy repo..."
cd "$DEPLOY_DIR"
commit_if_needed "$DEPLOY_DIR" "$MESSAGE" "deploy"
sync_branch "$DEPLOY_DIR" "$DEPLOY_REMOTE" "$DEPLOY_BRANCH" "deploy"
git push -u "$DEPLOY_REMOTE" "$DEPLOY_BRANCH"

echo "==> Done."
echo "Source repo pushed: $SOURCE_DIR"
echo "Deploy repo pushed: $DEPLOY_DIR"
