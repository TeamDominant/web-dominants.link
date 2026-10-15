#!/usr/bin/env bash
# Copies this repo into the mirror sites web-exds.tg and web-exds.wtf, which must sit next to it.
# The mirrors differ only by domain: https://dominants.link/ in the root HTML entry points becomes
# the mirror's domain, and the files in KEEP are never copied, overwritten or deleted.
#
#   scripts/sync.sh            copy and show what changed in each mirror
#   scripts/sync.sh --commit   also commit in each mirror with this repo's last commit message
#
# Pushing the mirrors is left to you.
set -euo pipefail

SOURCE_DOMAIN=dominants.link
MIRRORS=(web-exds.tg web-exds.wtf)
KEEP=(CNAME public/CNAME LICENSE scripts/sync.sh)

commit=false
case "${1:-}" in
  "") ;;
  --commit) commit=true ;;
  *) echo "usage: $0 [--commit]" >&2; exit 2 ;;
esac

src=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$src"

if $commit && [[ -n $(git status --porcelain) ]]; then
  echo "Commit your changes here first: the mirrors reuse the last commit message." >&2
  exit 1
fi

declare -A keep=() source=()
for f in "${KEEP[@]}"; do keep[$f]=1; done

# Tracked and new files; node_modules, dist and the rest of .gitignore are skipped.
while IFS= read -r -d '' f; do
  [[ -f $f && -z ${keep[$f]:-} ]] && source[$f]=1
done < <(git ls-files -z --cached --others --exclude-standard)

for mirror in "${MIRRORS[@]}"; do
  dst=$(realpath "$src/../$mirror")
  domain=${mirror#web-}

  if [[ ! -d $dst/.git ]]; then
    echo "$dst: not a git repository" >&2
    exit 1
  fi
  if [[ -n $(git -C "$dst" status --porcelain) ]]; then
    echo "$dst: has uncommitted changes, they would be overwritten. Commit or discard them first." >&2
    exit 1
  fi

  while IFS= read -r -d '' f; do
    [[ -z ${keep[$f]:-} && -z ${source[$f]:-} ]] && rm -f "$dst/$f"
  done < <(git -C "$dst" ls-files -z)

  for f in "${!source[@]}"; do
    mkdir -p "$dst/$(dirname "$f")"
    cp -p "$f" "$dst/$f"
  done
  sed -i "s|https://${SOURCE_DOMAIN//./\\.}/|https://$domain/|g" "$dst"/*.html

  echo "== $mirror"
  if [[ -z $(git -C "$dst" status --porcelain) ]]; then
    echo "up to date"
    continue
  fi
  git -C "$dst" status --short
  if $commit; then
    git -C "$dst" add -A
    git log -1 --format=%B | git -C "$dst" commit -q -F -
    git -C "$dst" log -1 --oneline
  fi
done
