#!/bin/bash
# install.sh in a scratch HOME: existing ~/.vimrc and ~/.vim are moved aside,
# a rerun changes nothing, check.sh runs. Usage: tests/installtest.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
h=$(mktemp -d); fail=0
mkdir -p "$h/.vim" && echo old > "$h/.vim/marker" && echo '" old' > "$h/.vimrc"
HOME=$h sh "$repo/install.sh" > "$h/out1" 2>&1 || { echo "FAIL install.sh exit $?"; fail=1; }
[ "$(readlink "$h/.vim")" = "$repo" ] && echo "PASS ~/.vim links to the repo" || { echo "FAIL link: $(ls -l "$h/.vim")"; fail=1; }
[ -f "$h/.vim.bak/marker" ] && echo "PASS old ~/.vim kept as ~/.vim.bak" || { echo "FAIL no ~/.vim.bak"; fail=1; }
[ -f "$h/.vimrc.bak" ] && [ ! -e "$h/.vimrc" ] && echo "PASS old ~/.vimrc moved aside" || { echo "FAIL ~/.vimrc"; fail=1; }
HOME=$h sh "$repo/install.sh" > "$h/out2" 2>&1
[ ! -e "$h/.vim.bak.1" ] && ! ls -A "$h" | grep -q 'bak\.' && echo "PASS rerun moves nothing" || { echo "FAIL rerun made backups"; fail=1; }
grep -q 'vim ' "$h/out1" && echo "PASS check.sh output shown" || { echo "FAIL no check.sh output"; cat "$h/out1"; fail=1; }
rm -rf "$h"
exit $fail
