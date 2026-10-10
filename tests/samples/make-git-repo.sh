#!/bin/sh
# Creates a throwaway git repo in DIR with one committed file f.txt
# (commit "add-f" by "Probe"). Usage: make-git-repo.sh DIR
set -e
rm -rf "$1" && mkdir -p "$1" && cd "$1"
git init -q
printf 'x\n' > f.txt
git add f.txt
git -c user.name=Probe -c user.email=probe@example.com commit -q -m add-f
