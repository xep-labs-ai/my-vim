# vim-tiny only (no +eval)
FROM debian:12
RUN apt-get update && apt-get install -y --no-install-recommends vim-tiny tmux && rm -rf /var/lib/apt/lists/*
