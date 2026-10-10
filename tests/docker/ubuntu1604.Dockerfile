# vim 7.4.1689: has packages, no TextYankPost, no timers in some builds
FROM ubuntu:16.04
RUN apt-get update && apt-get install -y vim tmux git && rm -rf /var/lib/apt/lists/*
