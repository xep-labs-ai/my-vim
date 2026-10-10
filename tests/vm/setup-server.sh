#!/bin/bash
# One-time setup of the server test VM (Ubuntu 24.04 with Docker). Needs sudo
# and internet. Run there: bash ~/my-vim/tests/vm/setup-server.sh
# Puts every optional tool under /opt/myvim-tools so run-matrix.sh can turn
# them on (case "tools") and off (case "bare") with PATH. Expects my-tmux in
# ~/projects/my-tmux (copied there by the dev machine).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
sudo apt-get update -q
sudo apt-get install -yq locales vim tmux mosh git fzf python3-venv curl xz-utils
# the dev machine sends LC_ALL=en_US.UTF-8 over ssh
sudo locale-gen en_US.UTF-8 >/dev/null
T=/opt/myvim-tools
sudo mkdir -p $T/bin && sudo chown -R "$(id -u):$(id -g)" $T
node=$(curl -fsSL https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt | awk '/linux-x64\.tar\.xz$/ {print $2}')
curl -fsSL "https://nodejs.org/dist/latest-v22.x/$node" | tar -xJ -C $T
ln -sfn "$T/${node%.tar.xz}" $T/node
ln -sf $T/node/bin/node $T/bin/node
PATH=$T/bin:$T/node/bin:$PATH npm install -g --prefix $T pyright yaml-language-server bash-language-server \
  @ansible/ansible-language-server typescript typescript-language-server vscode-langservers-extracted prettier eslint_d
python3 -m venv $T/venv
$T/venv/bin/pip install -q yamllint pylint ansible-lint black isort
for b in $T/venv/bin/yamllint $T/venv/bin/pylint $T/venv/bin/ansible* $T/venv/bin/black $T/venv/bin/isort; do
  ln -sf "$b" $T/bin/
done
curl -fsSL https://github.com/junegunn/fzf/releases/download/v0.74.4/fzf-0.74.4-linux_amd64.tar.gz | tar -xz -C $T/bin fzf
curl -fsSL https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /tmp
cp /tmp/ripgrep-14.1.1-x86_64-unknown-linux-musl/rg $T/bin/
curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz | tar -xJ -C /tmp
cp /tmp/shellcheck-v0.10.0/shellcheck $T/bin/
(cd ~/projects/my-tmux && ./install.sh)
bash ~/my-vim/tests/docker/build.sh
echo "server setup done"
