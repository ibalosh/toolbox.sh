#!/usr/bin/env bash
set -euo pipefail

DAYS=14
PROTECTED_BRANCHES="^(main|master|develop)$"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)
      DAYS="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--days N] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

echo "🧹 Cleaning local branches older than $DAYS days (excluding main/master/develop)"
echo

# Cross-platform date math
if date -d "now" >/dev/null 2>&1; then
  # GNU date (Linux)
  CUTOFF=$(date -d "$DAYS days ago" +%s)
else
  # BSD date (macOS)
  CUTOFF=$(date -v -"${DAYS}"d +%s)
fi

BRANCHES=$(git for-each-ref --sort=committerdate --format='%(committerdate:short) %(refname:short)' refs/heads/ \
  | awk -v limit="$CUTOFF" '{
      cmd = "date -j -f %Y-%m-%d " $1 " +%s 2>/dev/null || date -d " $1 " +%s 2>/dev/null";
      cmd | getline t;
      close(cmd);
      if (t < limit) print $2;
    }' \
  | grep -v -E "$PROTECTED_BRANCHES" || true)

if [[ -z "$BRANCHES" ]]; then
  echo "✅ No branches older than $DAYS days found."
  exit 0
fi

echo "These branches are older than $DAYS days:"
echo "$BRANCHES" | sed 's/^/  - /'
echo

if [[ "${DRY_RUN:-false}" == true ]]; then
  echo "Dry run: no branches deleted."
  exit 0
fi

read -rp "❓ Delete these branches? [y/N] " CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "$BRANCHES" | xargs -r git branch -D
  echo
  echo "🗑️  Deleted old branches."
else
  echo "❎ Cancelled."
fi