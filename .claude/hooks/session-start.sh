#!/bin/bash
# SessionStart hook for cloud sessions. Two jobs:
#   1. Teammate safety: fetch every branch and tell Claude which branches hold work that isn't in this one, so
#      it builds on that work instead of overwriting or reverting it (see CLAUDE.md).
#   2. Tools: install Rojo (version from rokit.toml) and Lune for the build and compile checks.
# Never fails the session: every step is best effort.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR" || exit 0
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
echo "export PATH=\"$BIN:\$PATH\"" >> "${CLAUDE_ENV_FILE:-/dev/null}"
export PATH="$BIN:$PATH"

# --- tools -------------------------------------------------------------------------------------------------
install_zip() { # name url
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL --max-time 60 -o "$tmp/t.zip" "$2" && unzip -qo "$tmp/t.zip" -d "$tmp/x"; then
    find "$tmp/x" -type f -name "$1" -exec install -m 755 {} "$BIN/$1" \;
  fi
  rm -rf "$tmp"
}
ROJO_VERSION=$(sed -n 's/^rojo = "rojo-rbx\/rojo@\(.*\)"/\1/p' rokit.toml 2>/dev/null)
ROJO_VERSION=${ROJO_VERSION:-7.7.1}
if ! command -v rojo >/dev/null 2>&1; then
  install_zip rojo "https://github.com/rojo-rbx/rojo/releases/download/v${ROJO_VERSION}/rojo-${ROJO_VERSION}-linux-x86_64.zip"
fi
if ! command -v lune >/dev/null 2>&1; then
  install_zip lune "https://github.com/lune-org/lune/releases/download/v0.8.9/lune-0.8.9-linux-x86_64.zip"
fi

# --- teammate safety ---------------------------------------------------------------------------------------
git fetch --all --prune --quiet 2>/dev/null || true
current=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

echo "=== TEAM SAFETY CHECK (from .claude/hooks/session-start.sh) ==="
echo "You are on branch: ${current}. Read CLAUDE.md before changing anything."
upstream="origin/${current}"
if git rev-parse --verify --quiet "$upstream" >/dev/null; then
  behind=$(git rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)
  if [ "${behind:-0}" -gt 0 ]; then
    echo "!! ${upstream} has ${behind} commit(s) you don't have. Run: git pull origin ${current}"
  fi
fi
found=0
for ref in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v -E '^origin/HEAD$|^origin$'); do
  [ "$ref" = "$upstream" ] && continue
  ahead=$(git rev-list --count "HEAD..$ref" 2>/dev/null || echo 0)
  [ "${ahead:-0}" -eq 0 ] && continue
  last=$(git log -1 --format='%cr' "$ref" 2>/dev/null)
  # only flag branches touched in the last 30 days; older ones are history
  if [ -n "$(git log -1 --since='30 days ago' --format=%h "$ref" 2>/dev/null)" ]; then
    found=1
    echo "!! ${ref}: ${ahead} commit(s) not in your branch (last ${last}). Files it changed:"
    base=$(git merge-base HEAD "$ref" 2>/dev/null)
    git diff --name-only "$base" "$ref" 2>/dev/null | grep -E '\.luau$|\.json$' | head -15 | sed 's/^/     /'
  fi
done
if [ "$found" -eq 1 ]; then
  echo "Those branches hold teammates' work. Do NOT overwrite or revert it. Before editing any file listed above,"
  echo "tell the user and ask whether to merge that branch in first (git merge, never reset/force-push)."
else
  echo "No recent branch has work missing from yours."
fi
echo "=== END TEAM SAFETY CHECK ==="
exit 0
