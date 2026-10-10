#!/bin/bash
# Vendors the plugins in plugins.list into pack/vendor/opt/<name> (no .git),
# rewrites plugins.list with full commit SHAs and rebuilds the help tags.
# Dev machine only (needs git and network); commit the result.
#   ./update-plugins.sh             vendor every plugin at its pinned commit
#   ./update-plugins.sh --bump      move every pin to the remote HEAD first
#   ./update-plugins.sh --bump NAME only that plugin moves
set -euo pipefail
cd "$(dirname "$0")"
bump=0; only=
[ "${1:-}" = --bump ] && { bump=1; only=${2:-}; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
: > "$tmp/list"
while IFS= read -r line; do
  case $line in ''|'#'*) echo "$line" >> "$tmp/list"; continue ;; esac
  read -r name url ref paths <<< "$line"
  if [ $bump = 1 ] && { [ -z "$only" ] || [ "$name" = "$only" ]; }; then
    ref=$(git ls-remote "$url" HEAD | cut -f1)
  fi
  git clone -q --filter=blob:none "$url" "$tmp/$name"
  git -C "$tmp/$name" checkout -q "$ref"
  ref=$(git -C "$tmp/$name" rev-parse HEAD)
  dest=pack/vendor/opt/$name
  rm -rf "$dest"; mkdir -p "$dest"
  # shellcheck disable=SC2086 # paths is a list of pathspecs
  git -C "$tmp/$name" archive HEAD -- ${paths:-.} | tar -x -C "$dest"
  printf '%-26s %-57s %s%s\n' "$name" "$url" "$ref" "${paths:+  $paths}" >> "$tmp/list"
  echo "vendored $name ${ref:0:12}"
done < plugins.list
mv "$tmp/list" plugins.list
rm -f pack/vendor/opt/*/doc/tags
vim -Nu NONE -es -c 'for d in glob("pack/vendor/opt/*/doc", 0, 1) | execute "helptags" fnameescape(d) | endfor' -c 'qa!'
du -sh pack/vendor
