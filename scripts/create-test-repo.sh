#!/usr/bin/env bash
# Create a disposable GitHub test repo under the logged-in gh account.
#
# Usage:
#   bash create-test-repo.sh                 # name: test-repo-YYYYMMDD-HHMMSS
#   bash create-test-repo.sh my-test-name    # custom name
#   VISIBILITY=private bash create-test-repo.sh
#
# Requires: gh auth login (repo scope), git
set -euo pipefail

NAME="${1:-test-repo-$(date -u +%Y%m%d-%H%M%S)}"
VISIBILITY="${VISIBILITY:-public}"   # public | private
OWNER="${OWNER:-$(gh api user --jq .login)}"
WORKDIR="${WORKDIR:-$HOME/code/$NAME}"
DESC="${DESC:-Disposable test repo created from VPS}"

case "$VISIBILITY" in
  public|private) ;;
  *) echo "ERROR: VISIBILITY must be public or private" >&2; exit 1 ;;
esac

if ! gh auth status >/dev/null 2>&1; then
  echo "ERROR: not logged into gh — run: gh auth login" >&2
  exit 1
fi

if gh repo view "$OWNER/$NAME" >/dev/null 2>&1; then
  echo "ERROR: repo already exists: https://github.com/$OWNER/$NAME" >&2
  exit 1
fi

echo "==> creating GitHub repo $OWNER/$NAME ($VISIBILITY)"
gh repo create "$OWNER/$NAME" \
  --"$VISIBILITY" \
  --description "$DESC" \
  --disable-wiki

mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [[ ! -d .git ]]; then
  git init -b main
fi

# Local identity only (do not touch global git config)
git config user.name "${GIT_USER_NAME:-$OWNER}"
git config user.email "${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || echo "${OWNER}@users.noreply.github.com")}"

cat > README.md <<EOF
# $NAME

Disposable test repository.

- Owner: \`$OWNER\`
- Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Tool: \`create-test-repo.sh\`
EOF

git add README.md
git commit -m "chore: initial commit"
git remote remove origin 2>/dev/null || true
git remote add origin "git@github.com:$OWNER/$NAME.git"
git push -u origin HEAD

echo
echo "OK: https://github.com/$OWNER/$NAME"
echo "    local: $WORKDIR"
gh repo view "$OWNER/$NAME" --json name,url,visibility,createdAt \
  --jq '"name=\(.name) visibility=\(.visibility) url=\(.url)"'
