#!/bin/bash
# Presses real keys in vim inside a private tmux and checks the result.
# Usage: tests/keytest.sh   (exit 1 on failure)
set -u
here=$(cd "$(dirname "$0")" && pwd)
T() { timeout 5 tmux -L keys -f "$here/probe-tmux.conf" "$@"; }
out=/tmp/myvim-keytest; rm -f $out.*
T kill-server 2>/dev/null
printf 'one\ntwo\n' > $out.txt
T new-session -d -s k -x 160 -y 40 "vim $out.txt"
sleep 2
w() { T send-keys -t k Escape ":call writefile([$1], '$out.$2')" Enter; sleep 0.5; }
T send-keys -t k ':vsplit' Enter; sleep 0.5
w 'winwidth(0)' w1
T send-keys -t k M-.; sleep 0.5
w 'winwidth(0)' w2
T send-keys -t k i x j k; sleep 0.5          # jk typed at human speed (> ttimeoutlen apart)
w 'mode() . getline(1)' m
T send-keys -t k Escape ':call myvim#harpoon#add()' Enter; sleep 0.5
T send-keys -t k Escape ':enew' Enter; sleep 0.5
T send-keys -t k M-h; sleep 0.5
w "expand('%:t')" h
T send-keys -t k Escape ':qa!' Enter; sleep 0.5
T kill-server 2>/dev/null
fail=0
[ "$(cat $out.w2)" -eq $(( $(cat $out.w1) + 2 )) ] && echo "PASS <M-.> widens by 2" || { echo "FAIL <M-.>: $(cat $out.w1) -> $(cat $out.w2)"; fail=1; }
[ "$(cat $out.m)" = nxone ] && echo "PASS jk leaves insert" || { echo "FAIL jk: $(cat $out.m)"; fail=1; }
[ "$(cat $out.h)" = "$(basename $out.txt)" ] && echo "PASS <M-h> opens harpoon 1" || { echo "FAIL <M-h>: $(cat $out.h)"; fail=1; }
exit $fail
