#!/bin/sh
# Builds a folder to copy to a server's ~/.vim as is: the config plus only
# the plugins of one size (no tests, docs or git). Run it on a machine that
# has the repo; the server needs no internet or git.
#   sh bundle.sh tiny|small [DIR]    (default DIR: vim_tiny / vim_small here)
# install_tiny.sh and install_small.sh call this.
set -eu
repo=$(cd "$(dirname "$0")" && pwd)
v=${1:-}
# Most important first; small is tiny plus its own list.
tiny="vim-tmux-navigator vim-commentary vim-surround vim-repeat ReplaceWithRegister ctrlp.vim"
small="$tiny nerdtree lightline.vim vim-fugitive vim-gitgutter undotree vim-maximizer vim-nightfly-colors indentLine auto-pairs"
case $v in
  tiny) plugins=$tiny ;;
  small) plugins=$small ;;
  *) echo "usage: sh bundle.sh tiny|small [DIR]" >&2; exit 2 ;;
esac
dir=${2:-$repo/vim_$v}

# replace only a folder this script built (it has a BUNDLE file)
if [ -e "$dir" ]; then
  [ -f "$dir/BUNDLE" ] || { echo "$dir exists and isn't a bundle; not touching it" >&2; exit 1; }
  rm -rf "$dir"
fi
mkdir -p "$dir/pack/vendor/opt"
cd "$repo"
tar -cf - vimrc README.md install.sh check.sh plugin autoload ftdetect after | tar -xf - -C "$dir"
for p in $plugins; do
  [ -d "pack/vendor/opt/$p" ] || { echo "missing pack/vendor/opt/$p" >&2; exit 1; }
  tar -cf - "pack/vendor/opt/$p" | tar -xf - -C "$dir"
done
# read by check.sh: the size, then the plugins it should load
printf '%s\n%s\n' "$v" "$plugins" > "$dir/BUNDLE"
echo "built $dir ($(du -sh "$dir" | cut -f1)): $plugins"
echo "copy it to a server that has no ~/.vim yet, then install (moves ~/.vimrc aside, runs check.sh):"
echo "  scp -r $dir user@server:.vim && ssh user@server sh .vim/install.sh"
