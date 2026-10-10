#!/bin/bash
# Builds image myvim-test:NAME from each tests/docker/NAME.Dockerfile.
# Usage: tests/docker/build.sh [NAME...]
set -euo pipefail
cd "$(dirname "$0")"
names=${*:-$(ls *.Dockerfile | sed 's/\.Dockerfile$//')}
for n in $names; do
  echo "building myvim-test:$n"
  docker build -q -t "myvim-test:$n" -f "$n.Dockerfile" .
done
