#!/bin/sh
# Links ~/.vim to this repo (vim then reads ~/.vim/vimrc). Moves an existing
# ~/.vim to ~/.vim.bak and ~/.vimrc to ~/.vimrc.bak (~/.vimrc would win over
# ~/.vim/vimrc). Safe to rerun; no sudo, no network. Runs check.sh at the end.
set -eu
repo=$(cd "$(dirname "$0")" && pwd -P)
stamp=$(date +%Y%m%d-%H%M%S)

aside() {  # move $1 out of the way unless it already is the link to the repo
  if [ -L "$1" ] && [ "$(readlink "$1")" = "$repo" ]; then return 0; fi
  if [ -e "$1" ] || [ -L "$1" ]; then
    dest="$1.bak"
    [ -e "$dest" ] || [ -L "$dest" ] && dest="$1.bak.$stamp"
    mv "$1" "$dest"
    echo "moved $1 to $dest"
  fi
}

if [ "$repo" != "$(cd ~ && pwd -P)/.vim" ]; then
  aside "$HOME/.vim"
  [ -L "$HOME/.vim" ] || ln -s "$repo" "$HOME/.vim"
fi
aside "$HOME/.vimrc"
echo "my-vim: ~/.vim -> $repo"
sh "$repo/check.sh" || true
