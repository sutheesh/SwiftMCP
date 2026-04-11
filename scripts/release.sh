#!/bin/bash
set -euo pipefail

# ── SwiftMCP Release Script ──────────────────────────────────────
# Usage:  ./scripts/release.sh 1.1.0
#
# Workflow:
#   1. You work on 'develop' as usual
#   2. When ready to release, run this script from 'develop'
#   3. It merges develop → main, tags main, pushes everything
#   4. GitHub Actions builds, tests, and publishes the Release
# ─────────────────────────────────────────────────────────────────

VERSION="${1:-}"

if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "  e.g. ./scripts/release.sh 1.1.0"
  exit 1
fi

# Validate semver
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$'; then
  echo "❌ Invalid version: '$VERSION' (expected semver like 1.1.0 or 2.0.0-beta.1)"
  exit 1
fi

# Must start from develop
BRANCH=$(git branch --show-current)
if [ "$BRANCH" != "develop" ]; then
  echo "❌ You must be on 'develop' to release. Currently on '$BRANCH'."
  exit 1
fi

# Working tree must be clean
if [ -n "$(git status --porcelain)" ]; then
  echo "❌ Working tree is dirty. Commit or stash changes first."
  exit 1
fi

# Tag must not exist
if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "❌ Tag '$VERSION' already exists."
  exit 1
fi

# Check CHANGELOG
if ! grep -q "\[$VERSION\]" CHANGELOG.md; then
  echo "⚠️  No entry for [$VERSION] in CHANGELOG.md. Continue? (y/N)"
  read -r CONFIRM
  [ "$CONFIRM" = "y" ] || exit 0
fi

echo "── Local build & test ─────────────────────────────"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build 2>&1 | tail -3
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test 2>&1 | tail -5

echo "── Merging develop → main ─────────────────────────"
git checkout main
git pull origin main
git merge develop --no-ff -m "Release $VERSION"

echo "── Tagging $VERSION on main ───────────────────────"
git tag -a "$VERSION" -m "SwiftMCP $VERSION"

echo "── Pushing main + tag ─────────────────────────────"
git push origin main
git push origin "$VERSION"

echo "── Back to develop ────────────────────────────────"
git checkout develop
git merge main --no-ff -m "Merge main back after $VERSION release"
git push origin develop

echo ""
echo "✅ Released $VERSION"
echo ""
echo "   main    ← merged from develop, tagged $VERSION"
echo "   develop ← synced with main"
echo ""
echo "   GitHub Actions will publish the release:"
echo "   https://github.com/sutheesh/SwiftMCP/actions"
