#!/bin/bash
# Copies this working tree to HOST:~/my-vim (replacing it, .state included)
# and installs it. Usage: tests/push.sh user@host
set -euo pipefail
host=$1
cd "$(dirname "$0")/.."
tar --exclude=.git --exclude=.state --exclude=.superpowers --exclude='.claude/*.local' -cf - . |
  ssh "$host" 'rm -rf ~/my-vim.new && mkdir -p ~/my-vim.new && tar -x -C ~/my-vim.new && chmod -R u+w ~/my-vim 2>/dev/null; rm -rf ~/my-vim && mv ~/my-vim.new ~/my-vim'
ssh "$host" 'if [ -f ~/my-vim/install.sh ]; then LC_ALL=C.UTF-8 sh ~/my-vim/install.sh >/dev/null; else ln -sfn ~/my-vim ~/.vim; fi'
