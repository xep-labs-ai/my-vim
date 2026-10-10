#!/bin/bash
# One-time setup of the client test VM (Ubuntu 24.04): tmux, mosh, my-tmux
# (copied to ~/projects/my-tmux by the dev machine) and an ssh key whose
# public half goes into the server's authorized_keys.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
sudo apt-get update -q
sudo apt-get install -yq locales tmux mosh python3 git
# the dev machine sends LC_ALL=en_US.UTF-8 over ssh
sudo locale-gen en_US.UTF-8 >/dev/null
(cd ~/projects/my-tmux && ./install.sh)
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
