#!/bin/bash
# Prints the problems in a probe report (OUT and OUT.screen); exit 1 if any.
r=$1
bad=0
grep -q '^DONE' "$r" 2>/dev/null || { echo "  no DONE: the probe never finished (startup prompt or hang?)"; bad=1; }
grep '^FAIL' "$r" 2>/dev/null && bad=1
grep -E '^MSG .*(E[0-9]+:|Error)' "$r" 2>/dev/null && bad=1
grep -E '^errmsg=.' "$r" 2>/dev/null && bad=1
grep -E 'Press ENTER|E[0-9]{2,4}:' "$r.screen" 2>/dev/null | sed 's/^/  screen: /' | grep . && bad=1
[ $bad = 0 ] && echo "  ok ($(grep -c '^PASS' "$r") passed, $(grep -c '^SKIP' "$r") skipped)"
exit $bad
