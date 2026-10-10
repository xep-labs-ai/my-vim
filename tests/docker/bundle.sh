#!/bin/bash
# Runs tests/bundletest.sh VARIANT inside image myvim-test:NAME with no
# network (an offline server). Usage: tests/docker/bundle.sh NAME tiny|small
set -u
name=$1; v=$2
repo=$(cd "$(dirname "$0")/../.." && pwd)
docker run --rm --network none -v "$repo:/src:ro" "myvim-test:$name" bash -c '
  cp -r /src ~/my-vim && rm -rf ~/my-vim/.state ~/my-vim/vim_tiny ~/my-vim/vim_small
  ~/my-vim/tests/bundletest.sh '"$v"
