#!/bin/bash
# install_tiny.sh / install_small.sh build a folder that is copied to a
# server's ~/.vim as is (scp -r). In a scratch HOME that already has a
# ~/.vimrc: check.sh warns about it, install.sh moves it aside, then check.sh
# and a real vim start load exactly the bundle's plugins without errors.
# Usage: tests/bundletest.sh tiny|small
set -u
v=$1
repo=$(cd "$(dirname "$0")/.." && pwd)
tiny="vim-tmux-navigator vim-commentary vim-surround vim-repeat ReplaceWithRegister ctrlp.vim"
small="$tiny nerdtree lightline.vim vim-fugitive vim-gitgutter undotree vim-maximizer vim-nightfly-colors indentLine auto-pairs"
case $v in tiny) want=$tiny ;; small) want=$small ;; *) echo "usage: $0 tiny|small"; exit 2 ;; esac
sorted() { tr ' ' '\n' | sed '/^$/d' | sort | tr '\n' ' '; }
fail=0
pass() { echo "PASS $1"; }
bad()  { echo "FAIL $1"; fail=1; }

b=$(mktemp -d); h=$(mktemp -d)
sh "$repo/install_$v.sh" "$b/vim_$v" > "$b/build.out" 2>&1 || bad "install_$v.sh exit $?: $(cat "$b/build.out")"
[ -f "$b/vim_$v/vimrc" ] && pass "vim_$v has vimrc" || bad "no vim_$v/vimrc"
got=$(ls "$b/vim_$v/pack/vendor/opt" 2>/dev/null | sorted)
[ "$got" = "$(echo "$want" | sorted)" ] && pass "vim_$v plugins: $want" || bad "vim_$v plugins: '$got'"
for x in tests docs .git .claude .superpowers .state plugins.list update-plugins.sh; do
  [ -e "$b/vim_$v/$x" ] && bad "vim_$v contains $x"
done
# a rebuild over the old folder replaces it
sh "$repo/install_$v.sh" "$b/vim_$v" > "$b/build2.out" 2>&1 && pass "rebuild over the old folder" || bad "rebuild: $(cat "$b/build2.out")"

# scp -r vim_$v server:.vim, on a server with its own ~/.vimrc
cp -r "$b/vim_$v" "$h/.vim"
echo '" old' > "$h/.vimrc"
HOME=$h sh "$h/.vim/check.sh" > "$h/check1" 2>&1
rc=$?
grep -q 'WARN.*\.vimrc' "$h/check1" && [ $rc != 0 ] && pass "check.sh warns about ~/.vimrc" || { bad "check.sh with ~/.vimrc (exit $rc)"; cat "$h/check1"; }

HOME=$h sh "$h/.vim/install.sh" > "$h/install" 2>&1
[ -f "$h/.vimrc.bak" ] && [ ! -e "$h/.vimrc" ] && pass "install.sh moved ~/.vimrc aside" || bad "~/.vimrc not moved"
[ -d "$h/.vim" ] && [ ! -L "$h/.vim" ] && [ ! -e "$h/.vim.bak" ] && pass "~/.vim left in place" || bad "~/.vim moved: $(ls -la "$h")"

HOME=$h sh "$h/.vim/check.sh" > "$h/check2" 2>&1
rc=$?
[ $rc = 0 ] && pass "check.sh exit 0" || { bad "check.sh exit $rc"; cat "$h/check2"; }
grep -q "bundle: $v" "$h/check2" && pass "check.sh names the bundle" || { bad "check.sh doesn't name the bundle"; cat "$h/check2"; }
loaded=$(sed -n 's/^  ok    plugins: //p' "$h/check2" | sorted)
[ "$loaded" = "$(echo "$want" | sorted)" ] && pass "check.sh: all bundle plugins load" || bad "check.sh plugins: '$loaded'"
grep -q 'language-server' "$h/check2" && bad "check.sh lists language servers the bundle can't use"

# a real start: no -u, so vim must find ~/.vim/vimrc by itself
out=$h/vimstart
HOME=$h TERM=xterm vim -N -i NONE -c "redir => g:m | silent messages | redir END" \
  -c "call writefile([join(sort(copy(get(g:, 'myvim_plugins', ['none']))), ' '), substitute(g:m, '\n', ' | ', 'g')], '$out')" \
  -c 'qa!' "$h/.vim/vimrc" </dev/null >/dev/null 2>&1
started=$(sed -n 1p "$out" 2>/dev/null | sorted)
[ "$started" = "$(echo "$want" | sorted)" ] && pass "vim started with the bundle's plugins" || bad "vim start plugins: '$started'"
sed -n 2p "$out" 2>/dev/null | grep -q 'E[0-9]\+:' && bad "errors at start: $(sed -n 2p "$out")" || pass "no errors at start"

rm -rf "$b" "$h"
exit $fail
