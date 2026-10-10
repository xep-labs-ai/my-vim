#!/bin/bash
# Server side of the clipboard chain test (tests/cliptest/cliptest.py).
#   remote.sh prepare TOKEN   write ~/t/yank.txt, kill any old "nv" session
#   remote.sh ready           exit 0 once session nv runs vim (leaves my-tmux's view mode first)
#   remote.sh run TOKEN       yank line 2, check the tmux buffer, paste with p, then
#                             paste a buffer "another pane" set, report RESULT lines
# TMUX_CMD runs tmux (default "tmux"; e.g. "tmux -L stock", "docker exec cliprocky8 tmux").
# RUN prefixes commands that must run where vim runs (e.g. "docker exec cliprocky8").
# T_HOME is the home vim sees (default $HOME).
export LC_ALL=C.UTF-8
TMUX_CMD=${TMUX_CMD:-tmux}
RUN=${RUN:-}
T_HOME=${T_HOME:-$HOME}
T() { timeout 5 $TMUX_CMD "$@"; }
R() { $RUN "$@"; }
case $1 in
prepare)
  T kill-session -t nv 2>/dev/null
  R sh -c "rm -f /tmp/prov /tmp/after-p.txt $T_HOME/.vim/.state/swap/*yank.txt.sw?; mkdir -p $T_HOME/t; printf 'first line\n%s\nlast line\n' '$2' > $T_HOME/t/yank.txt" ;;
ready)
  [ "$(T list-panes -t nv -F '#{pane_current_command}' 2>/dev/null)" = vim ] || exit 1
  for i in 1 2 3; do
    [ "$(T display -p -t nv '#{pane_in_mode}')" = 1 ] && T send-keys -t nv -X cancel
    sleep 0.3
  done
  [ "$(T display -p -t nv '#{pane_in_mode}')" = 0 ] ;;
run)
  TOKEN=$2
  T send-keys -t nv Escape ":call writefile(['mode=' . g:myvim_clip_mode, 'TMUX=' . \$TMUX, 'version=' . v:version], '/tmp/prov')" Enter; sleep 1
  echo "vim sees: $(R cat /tmp/prov 2>/dev/null | tr '\n' ' ')"
  T set-buffer -b marker before-yank
  T send-keys -t nv Escape g g j y y; sleep 2
  echo "tmux buffers after yy:"; T list-buffers -F '  #{buffer_name}: #{buffer_sample}'
  T list-buffers -F '#{buffer_sample}' | grep -q "$TOKEN" && echo "RESULT tmux-buffer: OK" || echo "RESULT tmux-buffer: MISSING"
  T send-keys -t nv G p; sleep 1
  T send-keys -t nv Escape ":w! /tmp/after-p.txt" Enter; sleep 1
  [ "$(R grep -c "$TOKEN" /tmp/after-p.txt 2>/dev/null)" -ge 2 ] && echo "RESULT paste-own: OK" || echo "RESULT paste-own: FAILED"
  # a copy in another pane: -w (tmux 3.2+) also sends it to the client clipboard,
  # as copy mode does; an outer tmux answering refresh-client -l then has it too
  T set-buffer -w -- "pane-$TOKEN" 2>/dev/null || T set-buffer -- "pane-$TOKEN"
  T send-keys -t nv G p; sleep 1
  T send-keys -t nv Escape ":w! /tmp/after-p.txt" Enter; sleep 1
  R grep -q "pane-$TOKEN" /tmp/after-p.txt && echo "RESULT paste-other-pane: OK" || echo "RESULT paste-other-pane: FAILED"
  echo "file after the pastes:"; R sed 's/^/  /' /tmp/after-p.txt
  T capture-pane -p -t nv | grep -iE 'Press ENTER|error|E[0-9]{3,4}:' | sed 's/^/  screen: /'
  T send-keys -t nv Escape ":qa!" Enter; sleep 1
  T kill-session -t nv 2>/dev/null ;;
esac
