#!/bin/bash
# Starts vim on FILE... in a private tmux server, runs tests/probe.vim once vim
# has started, and writes the report to OUT and the last screen to OUT.screen.
# Usage: tests/run-probe.sh OUT FILE...   (FILE relative to the repo, or absolute)
# VIMBIN picks the binary (default vim). vim.tiny can't run the probe: it only
# gets a screen check (no errors, and relativenumber from ~/.vim/vimrc).
set -u
out=$1; shift
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
export LC_ALL=${LC_ALL:-C.UTF-8} PROBE_OUT=$out
vimbin=${VIMBIN:-vim}
files=()
for f in "$@"; do
  case $f in /*) files+=("$f") ;; *) files+=("$repo/$f") ;; esac
done
T() { timeout 5 tmux -L probe -f "$here/probe-tmux.conf" "$@"; }
rm -f "$out" "$out.screen"
T kill-server 2>/dev/null
cd ~ || exit 1
if [ "${vimbin##*/}" = vim.tiny ]; then
  T new-session -d -s p -x 200 -y 50 "$vimbin ${files[*]}"
  sleep 3
  T capture-pane -p -t p > "$out.screen"
  T send-keys -t p Escape ':qa!' Enter
  sleep 1
  if sed -n 2p "$out.screen" | grep -qE '^ +1 '; then
    echo "PASS vim.tiny read ~/.vim/vimrc (relativenumber)" > "$out"
  else
    echo "FAIL vim.tiny did not read ~/.vim/vimrc (no relativenumber)" > "$out"
  fi
  echo DONE >> "$out"
else
  T new-session -d -s p -x 200 -y 50 "$vimbin -c 'source $here/probe.vim' ${files[*]}"
  for _ in $(seq 1 240); do
    grep -qs '^DONE' "$out" && break
    T capture-pane -p -t p > "$out.screen" 2>/dev/null
    sleep 0.5
  done
  T capture-pane -p -t p > "$out.screen" 2>/dev/null
  # quit before the kill, or a changed buffer leaves a swap file for the next run
  T send-keys -t p Escape ':qa!' Enter 2>/dev/null
  sleep 0.5
fi
T kill-server 2>/dev/null
"$here/check-report.sh" "$out"
