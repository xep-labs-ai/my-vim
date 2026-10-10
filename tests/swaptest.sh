#!/bin/bash
# Leaves a swap file with unsaved changes, reopens the file, recovers, and
# checks vim asks to delete the swap. Usage: tests/swaptest.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
T() { timeout 5 tmux -L swap -f "$here/probe-tmux.conf" "$@"; }
f=/tmp/myvim-swaptest.txt; rm -f "$f"; printf 'saved\n' > "$f"
rm -f ~/.vim/.state/swap/*myvim-swaptest* ~/.local/state/my-vim/swap/*myvim-swaptest*
T kill-server 2>/dev/null
T new-session -d -s s -x 160 -y 40 "vim $f"; sleep 2
T send-keys -t s o unsaved Escape; sleep 1.5      # unsaved change, swap written (updatetime 300)
T kill-server; sleep 0.5                           # vim dies, swap stays
T new-session -d -s s -x 160 -y 40 "vim $f"; sleep 2
T send-keys -t s r; sleep 1                        # (R)ecover at the ATTENTION prompt
T send-keys -t s Enter; sleep 0.5
T send-keys -t s ':w' Enter; sleep 0.5             # recovered text saved: buffer unmodified
T send-keys -t s ":e" Enter; sleep 1             # the old swap is still there: ATTENTION again
T send-keys -t s r; sleep 1                        # recover again: nothing left to recover
screen=$(T capture-pane -p -t s)
case $screen in *'Delete swap file?'*) ;; *) T send-keys -t s Enter; sleep 1; screen=$(T capture-pane -p -t s) ;; esac
T kill-server 2>/dev/null
grep -q 'unsaved' "$f" && echo "PASS recovered" || { echo "FAIL recovery"; exit 1; }
echo "$screen" | grep -q 'Delete swap file? (y/N)' && echo "PASS asks to delete swap" || { echo "FAIL no prompt"; echo "$screen"; exit 1; }
