#!/usr/bin/env python3
"""Clipboard chain test for my-vim. Usage: cliptest.py NAME REMOTE 'CLIENT COMMAND'

Runs CLIENT COMMAND under `script` as a stand-in for the user's terminal
(TERM=xterm-256color) and records everything it receives. With tmux on the
server, the command must end in a tmux session "nv" running `vim ~/t/yank.txt`
and remote.sh (in ~/my-vim/tests/cliptest on REMOTE) yanks and pastes.
DRIVE=stdin: no tmux on the server; keys are typed into the terminal instead
(yank only). REMOTE_ENV: variables for remote.sh, e.g. 'TMUX_CMD="tmux -L stock"'.
LOCAL_CHECK: command run here before teardown (e.g. the outer tmux's buffers).
Reports the OSC 52 sequences that reached the client terminal."""
import base64, os, random, re, subprocess, sys, time

name, remote, client = sys.argv[1:4]
here = os.path.dirname(os.path.abspath(__file__))
rec = os.path.join(here, f"rec-{name}.raw")
token = f"yank-{name}-{random.randint(10**8, 10**9)}"
renv = os.environ.get("REMOTE_ENV", "")
stdin_drive = os.environ.get("DRIVE") == "stdin"

def ssh(cmd, timeout=60):
    r = subprocess.run(["ssh", "-o", "BatchMode=yes", remote, f"{renv} {cmd}"], capture_output=True, text=True, timeout=timeout)
    return r.returncode, r.stdout

ssh(f"bash ~/my-vim/tests/cliptest/remote.sh prepare {token}")
if os.path.exists(rec):
    os.remove(rec)
env = dict(os.environ, TERM="xterm-256color", LC_ALL="C.UTF-8")
env.pop("TMUX", None)
# script's pty is 0x0 when stdin is a pipe (mosh-client aborts on that): give it a size
sized = "stty rows 40 cols 160 2>/dev/null; exec " + client
proc = subprocess.Popen(["script", "-qfc", sized, rec], stdin=subprocess.PIPE,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env, start_new_session=True)
try:
    if stdin_drive:
        time.sleep(6)
        for keys in (b"\x1bggjyy", b"\x1b:qa!\r"):
            proc.stdin.write(keys); proc.stdin.flush(); time.sleep(2)
    else:
        for _ in range(60):
            time.sleep(1)
            if ssh("bash ~/my-vim/tests/cliptest/remote.sh ready", 30)[0] == 0:
                break
        else:
            print("RESULT setup: vim never came up in tmux session nv")
        time.sleep(1)
        _, out = ssh(f"bash ~/my-vim/tests/cliptest/remote.sh run {token}", 120)
        print(out.replace(token, "<TOKEN>"), end="")
    if os.environ.get("LOCAL_CHECK"):
        r = subprocess.run(["bash", "-c", os.environ["LOCAL_CHECK"]], capture_output=True, text=True, timeout=30)
        print("local check:"); print("  " + r.stdout.replace(token, "<TOKEN>").replace("\n", "\n  "))
        print(f"RESULT local-tmux-buffer: {'OK' if token in r.stdout else 'MISSING'}")
finally:
    time.sleep(1)
    try:
        os.killpg(proc.pid, 15)
    except ProcessLookupError:
        pass
    proc.wait(timeout=10)

data = open(rec, "rb").read() if os.path.exists(rec) else b""
seqs = re.findall(rb"\x1b\]52;([a-z]*);([A-Za-z0-9+/=?]*)(?:\x07|\x1b\\)", data)
print(f"OSC 52 sequences that reached the client terminal: {len(seqs)}")
ok = False
for sel, b64 in seqs:
    if b64 == b"?":
        print(f"  selection={sel.decode() or '-'} query (asks the terminal for its clipboard)")
        continue
    text = base64.b64decode(b64).decode("utf-8", "replace")
    ok |= token in text
    print(f"  selection={sel.decode() or '-'} text={text.replace(token, '<TOKEN>')!r}")
print(f"RESULT client clipboard (OSC 52): {'OK' if ok else 'MISSING'}")
