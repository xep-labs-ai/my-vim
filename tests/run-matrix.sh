#!/bin/bash
# Runs the test cases on the server VM and prints PASS/FAIL per case plus the
# problems. Usage: tests/run-matrix.sh [CASE...]   (default: all cases)
#   tools          vim 9.1 with the LSP servers, linters and fzf in /opt/myvim-tools
#   tools-ansible  same, first file an Ansible role (ansiblels only, not yamlls)
#   bare           vim 9.1 without those tools (old apt fzf only)
#   keys           real key presses through tmux (Alt keys, jk)
#   readonly       bare, with the repo read-only (state dir falls back)
#   rocky8 rocky9 ubuntu1604 centos7 tiny   Docker images from tests/docker/
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
tools=/opt/myvim-tools/bin:/opt/myvim-tools/node/bin
samples="tests/samples/sample.py tests/samples/sample.yaml tests/samples/sample.sh tests/samples/sample.md"
cases=${*:-tools tools-ansible bare keys readonly rocky8 rocky9 ubuntu1604 centos7 tiny}
failed=0
for c in $cases; do
  out=/tmp/myvim-probe/$c/report
  mkdir -p "$(dirname "$out")"
  case $c in
    tools)         PROBE_TIER=2 PATH=$tools:$PATH "$here/run-probe.sh" "$out" $samples ;;
    tools-ansible) PROBE_TIER=2 PATH=$tools:$PATH "$here/run-probe.sh" "$out" tests/samples/ansible/roles/web/tasks/main.yml ;;
    keys)          "$here/keytest.sh" ;;
    bare)          PROBE_TIER=2 "$here/run-probe.sh" "$out" $samples ;;
    readonly)      chmod -R a-w "$repo"; PROBE_TIER=2 "$here/run-probe.sh" "$out" $samples; rc=$?; chmod -R u+w "$repo"; (exit $rc) ;;
    rocky8)        PROBE_TIER=1 "$here/docker/run.sh" "$c" "$out" $samples ;;
    rocky9)        PROBE_TIER=2 "$here/docker/run.sh" "$c" "$out" $samples ;;
    ubuntu1604)    PROBE_TIER=1 "$here/docker/run.sh" "$c" "$out" $samples ;;
    centos7)       PROBE_TIER=0 "$here/docker/run.sh" "$c" "$out" $samples ;;
    tiny)          "$here/docker/run.sh" "$c" "$out" tests/samples/sample.sh ;;
    *) echo "unknown case $c"; failed=1; continue ;;
  esac > "$out.check" 2>&1
  if [ $? = 0 ]; then echo "PASS $c"; else echo "FAIL $c"; sed 's/^/  /' "$out.check"; failed=1; fi
done
exit $failed
