#!/bin/bash
# Runs tests/run-probe.sh inside image myvim-test:NAME on a copy of the repo.
# Usage: tests/docker/run.sh NAME OUT FILE...   (OUT on the host, named "report"
# as run-matrix.sh names it; its directory is mounted at /out; FILE relative to the repo)
set -u
name=$1; out=$2; shift 2
repo=$(cd "$(dirname "$0")/../.." && pwd)
vimbin=vim; [ "$name" = tiny ] && vimbin=vim.tiny
mkdir -p "$(dirname "$out")"
docker run --rm -v "$repo:/src:ro" -v "$(dirname "$out"):/out" \
  -e VIMBIN=$vimbin -e PROBE_TIER="${PROBE_TIER:-}" "myvim-test:$name" bash -c '
    cp -r /src ~/my-vim
    if [ -f ~/my-vim/install.sh ]; then sh ~/my-vim/install.sh >/dev/null; else ln -sfn ~/my-vim ~/.vim; fi
    ~/my-vim/tests/run-probe.sh /out/report '"$*"' >/dev/null
    true'
"$repo/tests/check-report.sh" "$out"
