#!/bin/bash
# Client side of the nested test: start an outer tmux (own socket "outer",
# the user's config) whose pane runs CMD then stays open for the checks,
# leave the view mode my-tmux's display-message lines open, then attach.
# Usage: outer.sh CMD
tmux -L outer kill-server 2>/dev/null
tmux -L outer new-session -d -s outer -x 160 -y 40 "$1; sleep 60"
sleep 1
for i in 1 2 3; do
  [ "$(tmux -L outer display -p -t outer '#{pane_in_mode}')" = 1 ] && tmux -L outer send-keys -t outer -X cancel
  sleep 0.3
done
exec tmux -L outer attach -t outer
