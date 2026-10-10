# Port my-nvim to vim: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A vim configuration (this repo, linked as `~/.vim`) that gives vim on servers my-nvim's options, keymaps, look and plugin features, with clipboard that works through tmux, ssh and mosh, and LSP/lint only where the tools exist.

**Architecture:** `vimrc` decides a tier at startup (vim-tiny / 7.4 / 8.0+ / 8.2+ with jobs) and `packadd!`s vendored plugins from `pack/vendor/opt/` by condition. Own config lives in `plugin/*.vim` (thin: settings and mappings) with the logic in `autoload/myvim/*.vim`. Every behaviour is checked by a probe (`tests/probe.vim`) that runs inside a private tmux server on throwaway VMs and Docker containers with old vims.

**Tech Stack:** Vim script (must parse on vim 7.4), POSIX sh / bash for scripts, tmux, Docker, Python 3 (clipboard harness), PowerCLI (VM creation, from `~/projects/vibe-powercli`).

**Spec:** `docs/superpowers/specs/2026-10-10-nvim-to-vim-port-design.md`. Source config: `~/projects/my-nvim` (`main` e6c8f1b).

## Global Constraints

- Repo is public: no secrets, IP addresses, hostnames or machine-specific paths in committed files. VM IPs live in `.claude/vms.local` (git-ignored).
- Vim script must parse on vim 7.4 (no `vim9script`, no `++once`, no `<Cmd>`, no lambdas outside tier-2 files, no `trim()`, no `execute()` function). Tier-2 only files (`plugin/lsp.vim`, `autoload/myvim/lsp.vim`) may use vim 8.2 features.
- Tier 0 (`set` lines in `vimrc` outside `if 1`) must be options every vim build has.
- Every `plugin/*.vim` starts with `if !exists('g:myvim_tier') | finish | endif` (vim-tiny never gets here; 7.4 builds do).
- No startup messages and no "Press ENTER" in any case; a missing tool is silent (only `check.sh` reports it).
- Clipboard semantics are those of the spec's "Clipboard and tmux" section; selection parameter always `c`.
- Never test on the dev machine (`install.sh` replaces `~/.vim`); test on the VMs/containers of Task 1.
- Leader is `<Space>`. Keys are the ones in the spec's tables.
- **Ship procedure** (every task, per `.claude/CLAUDE.md`): on a branch from `origin/main`, commit with the attribution trailers, `git push -u origin <branch>`, `gh pr create --repo xep-labs-ai/my-vim --base main --head <branch>` with the matrix output in the body, `gh pr merge --repo xep-labs-ai/my-vim --merge --delete-branch`, then `git checkout main && git pull --ff-only && git branch -d <branch>`. Commit trailer lines:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_012WvFhPXtKJqSMWBGPhVSj4
  ```
- **Test loop** (dev machine, repo root): `SRV=$(sed -n 's/^server=//p' .claude/vms.local)`, then `tests/push.sh claude@$SRV && ssh claude@$SRV 'bash ~/my-vim/tests/run-matrix.sh <cases>'`.

## Review Focus

1. **`$TMUX` lost inside tmux** (`sudo -E`, `env -u TMUX`, containers): yank must still reach the client through plain OSC 52. Pinned by clipboard chain 6 (Task 6).
2. **tmux older than 3.2** (RHEL 8 ships 2.7: no `load-buffer -w`, no `refresh-client -l`): buffer + passthrough OSC 52, and `p` must still read the tmux buffer. Pinned by chain 8 (Task 6) and the `rocky8` case.
3. **Register prefix and count with the tmux `p` mapping**: `"ap` must paste register a without touching the tmux buffer, `3p` must paste three times. Pinned by scenarios in `tests/expect/40-clipboard.vim` (Task 6).
4. **Dotted filetype `yaml.ansible` with vim-lsp and ALE**: only ansible-language-server and ansible-lint, not yaml-language-server/yamllint. Pinned by case `tools-ansible` (Task 12).
5. **State dir not writable** (`~/.vim` read-only, e.g. a shared or root-owned checkout): falls back to `~/.local/state/my-vim`, no errors. Pinned by case `readonly` (Task 2).

---

## File map

```
vimrc                         tier detection, state dir, leader, plugin table, filetype/syntax
plugin/options.vim            options + terminal escapes + help/preview autocmds
plugin/terminal-keys.vim      <M-x> key codes for terminal vim
plugin/keymaps.vim            core keymaps (keymaps.lua + keymaps.vim)
plugin/scripts.vim            F5, preview scroll, <leader>hi, swap prompt, uc
plugin/clipboard.vim          clipboard mode, TextYankPost, p/P mappings, :MessagesToClipboard
plugin/plugins.vim            settings + keymaps for vendored tier-1 plugins
plugin/harpoon.vim            harpoon keymaps
plugin/blame.vim              line blame autocmds + <leader>fgSt
plugin/lsp.vim                tier 2: vim-lsp, asyncomplete, ALE
ftdetect/ansible.vim          yaml.ansible detection
after/ftplugin/yaml.vim       gf for yaml and yaml.ansible
autoload/myvim/window.vim     preview/help window helpers, PeditVertical, inspect
autoload/myvim/scripts.vim    toggle_number, clear_undo
autoload/myvim/swap.vim       swap-file prompt
autoload/myvim/clip.vim       clipboard backend
autoload/myvim/ansible.vim    role-aware gf
autoload/myvim/find.vim       finders (fzf.vim or ctrlp/grep)
autoload/myvim/tree.vim       NERDTree helpers
autoload/myvim/term.vim       terminal toggles
autoload/myvim/complete.vim   <CR> in insert mode (popup + auto-pairs)
autoload/myvim/colors.vim     highlight overrides
autoload/myvim/harpoon.vim    harpoon backend
autoload/myvim/blame.vim      line blame backend
autoload/myvim/lsp.vim        gl/gj definition-in-edge-window
autoload/lightline/colorscheme/myvim.vim   lualine colours
pack/vendor/opt/<plugin>/     vendored plugins
plugins.list, update-plugins.sh
install.sh, check.sh, README.md, .gitignore
tests/probe.vim, tests/probe-tmux.conf, tests/run-probe.sh, tests/check-report.sh,
tests/run-matrix.sh, tests/push.sh, tests/keytest.sh, tests/expect/*.vim,
tests/samples/..., tests/docker/*.Dockerfile, tests/docker/build.sh, tests/docker/run.sh,
tests/vm/setup-server.sh, tests/vm/setup-client.sh,
tests/cliptest/{cliptest.py,outer.sh,remote.sh}
```

---

### Task 1: Test harness and test VMs

Everything after this task is test-first through this harness, so it comes first and must prove it can fail.

**Files:**
- Create: `tests/probe.vim`, `tests/probe-tmux.conf`, `tests/run-probe.sh`, `tests/check-report.sh`, `tests/run-matrix.sh`, `tests/push.sh`, `tests/expect/00-startup.vim`
- Create: `tests/samples/sample.py`, `tests/samples/sample.yaml`, `tests/samples/sample.json`, `tests/samples/sample.sh`, `tests/samples/sample.md`, `tests/samples/make-git-repo.sh`, `tests/samples/ansible/ansible.cfg`, `tests/samples/ansible/playbooks/site.yml`, `tests/samples/ansible/roles/web/tasks/main.yml`, `tests/samples/ansible/roles/web/tasks/extra.yml`
- Create: `tests/docker/{rocky8,rocky9,ubuntu1604,centos7,tiny}.Dockerfile`, `tests/docker/build.sh`, `tests/docker/run.sh`
- Create: `tests/vm/setup-server.sh`, `tests/vm/setup-client.sh`
- Create: `.gitignore`

**Interfaces:**
- Produces: probe API used by every `tests/expect/*.vim`:
  - `Expect(cond, expr, want)`: evaluates `expr` (string) and compares type and value with `want`.
  - `ExpectMap(cond, mode, lhs)`: passes when `maparg(lhs, mode)` is non-empty.
  - `Scenario(cond, name, lines, setup, keys, expr, want)`: scratch buffer with `lines`, runs Ex `setup`, then `:normal keys` (mappings apply), then compares `eval(expr)` with `want`. Resets `v:errmsg` first, restores cwd/window/buffer after.
  - `WaitFor(expr, ms)`: returns 1 when `eval(expr)` becomes true within `ms` (sleeps 100 ms per try, which lets jobs run).
  - Conditions: `'eval'` (always), `'1'`/`'2'` (tier at least), `'fzf'`, `'nofzf'`, `'tmux'` (clip mode tmux), `'yankpost'` (`##TextYankPost` exists), `'lsp'` (an LSP server attached to the first buffer), `'lsp:<ft>'` (same and first buffer has that filetype), `'ale'` (tier 2 and `yamllint` on PATH), `'git'` (`git` on PATH), `'term'` (`has('terminal')`).
  - `$PROBE_TIER`: expected tier, checked by `00-startup.vim` when set.
- Produces: `tests/run-probe.sh OUT FILE...` (report in OUT, screen in OUT.screen, exit 1 on problems); `tests/run-matrix.sh [CASE...]` with cases `tools tools-ansible bare readonly rocky8 rocky9 ubuntu1604 centos7 tiny`; `tests/push.sh user@host`.

- [ ] **Step 1: Create the branch**

```bash
cd ~/projects/my-vim && git fetch origin && git checkout -b task-01-harness origin/main
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
# undo, swap, viminfo, harpoon lists (see vimrc)
/.state/
# VM addresses for the tests (never commit them: the repo is public)
/.claude/*.local
```

- [ ] **Step 3: Write `tests/probe.vim`**

```vim
" Test probe. tests/run-probe.sh starts vim with `-c 'source tests/probe.vim'`;
" the checks run once vim has started (after VimEnter, so plugins that start
" on VimEnter, like vim-lsp, are up). Every tests/expect/*.vim is sourced in
" order; each line of the report is PASS/FAIL/SKIP, then FAILS n and DONE.
let s:dir = expand('<sfile>:p:h')
let s:out = []
let s:fails = 0
let s:lsp_up = 0

function! s:ok(cond) abort
  let tier = get(g:, 'myvim_tier', -1)
  if a:cond ==# 'eval'
    return 1
  elseif a:cond =~# '^\d$'
    return tier >= str2nr(a:cond)
  elseif a:cond ==# 'fzf'
    return get(g:, 'myvim_fzf', 0)
  elseif a:cond ==# 'nofzf'
    return tier >= 1 && !get(g:, 'myvim_fzf', 0)
  elseif a:cond ==# 'tmux'
    return get(g:, 'myvim_clip_mode', '') ==# 'tmux'
  elseif a:cond ==# 'yankpost'
    return exists('##TextYankPost')
  elseif a:cond ==# 'lsp'
    return s:lsp_up
  elseif a:cond =~# '^lsp:'
    return s:lsp_up && &filetype ==# a:cond[4:]
  elseif a:cond ==# 'ale'
    return tier >= 2 && executable('yamllint')
  elseif a:cond ==# 'git'
    return executable('git')
  elseif a:cond ==# 'term'
    return has('terminal')
  endif
  throw 'probe: unknown condition ' . a:cond
endfunction

function! s:report(pass, what) abort
  call add(s:out, (a:pass ? 'PASS ' : 'FAIL ') . a:what)
  if !a:pass
    let s:fails += 1
  endif
endfunction

function! s:same(got, want) abort
  return type(a:got) == type(a:want) && a:got ==# a:want
endfunction

function! WaitFor(expr, ms) abort
  let waited = 0
  while waited < a:ms
    if eval(a:expr)
      return 1
    endif
    sleep 100m
    let waited += 100
  endwhile
  return eval(a:expr) ? 1 : 0
endfunction

function! Expect(cond, expr, want) abort
  if !s:ok(a:cond)
    call add(s:out, 'SKIP ' . a:expr)
    return
  endif
  try
    let got = eval(a:expr)
  catch
    let got = 'ERROR ' . v:exception
  endtry
  call s:report(s:same(got, a:want), printf('%s (got %s, want %s)', a:expr, string(got), string(a:want)))
endfunction

function! ExpectMap(cond, mode, lhs) abort
  if !s:ok(a:cond)
    call add(s:out, 'SKIP map ' . a:mode . ' ' . a:lhs)
    return
  endif
  call s:report(!empty(maparg(a:lhs, a:mode)), 'map ' . a:mode . ' ' . a:lhs)
endfunction

function! Scenario(cond, name, lines, setup, keys, expr, want) abort
  if !s:ok(a:cond)
    call add(s:out, 'SKIP ' . a:name)
    return
  endif
  let keep = bufnr('%')
  let cwd = getcwd()
  let v:errmsg = ''
  enew!
  setlocal buftype=nofile bufhidden=wipe noswapfile
  call setline(1, a:lines)
  call cursor(1, 1)
  try
    if !empty(a:setup)
      silent execute a:setup
    endif
    if !empty(a:keys)
      silent execute 'normal' a:keys
    endif
    let got = eval(a:expr)
  catch
    let got = 'ERROR ' . v:exception
  endtry
  call s:report(s:same(got, a:want), printf('%s (got %s, want %s)', a:name, string(got), string(a:want)))
  silent! only!
  silent! execute 'buffer!' keep
  silent! execute 'cd' fnameescape(cwd)
endfunction

function! s:messages() abort
  redir => m
  silent messages
  redir END
  return m
endfunction

function! s:main() abort
  " what startup left behind, before any check adds to it
  call add(s:out, 'errmsg=' . v:errmsg)
  for l in split(s:messages(), "\n")
    call add(s:out, 'MSG ' . l)
  endfor
  call add(s:out, 'tier=' . get(g:, 'myvim_tier', -1) . ' version=' . v:version . ' clip=' . get(g:, 'myvim_clip_mode', ''))
  " an LSP server registered for the first buffer's filetype: wait for it
  for fts in values(get(g:, 'myvim_lsp_servers', {}))
    if index(fts, &filetype) >= 0
      let s:lsp_up = WaitFor("exists('b:myvim_lsp')", 60000)
      call s:report(s:lsp_up, 'LSP attached to ' . expand('%:t'))
      break
    endif
  endfor
  for f in sort(split(glob(s:dir . '/expect/*.vim'), "\n"))
    try
      execute 'source' fnameescape(f)
    catch
      call s:report(0, fnamemodify(f, ':t') . ' threw ' . v:exception . ' at ' . v:throwpoint)
    endtry
  endfor
  call add(s:out, 'FAILS ' . s:fails)
  call add(s:out, 'DONE')
  call writefile(s:out, $PROBE_OUT)
endfunction

if has('vim_starting')
  augroup probe
    autocmd!
    autocmd VimEnter * call s:main()
  augroup END
else
  call s:main()
endif
```

- [ ] **Step 4: Write `tests/probe-tmux.conf`**

```tmux
# Private tmux server for tests/run-probe.sh (tmux 1.8+ syntax)
set -g default-terminal screen-256color
set -g escape-time 10
set -g history-limit 1000
```

- [ ] **Step 5: Write `tests/run-probe.sh`**

```bash
#!/bin/bash
# Starts vim on FILE... in a private tmux server, runs tests/probe.vim once vim
# has started, and writes the report to OUT and the last screen to OUT.screen.
# Usage: tests/run-probe.sh OUT FILE...   (FILE relative to the repo, or absolute)
# VIMBIN picks the binary (default vim). vim.tiny can't run the probe: it only
# gets a screen check (no errors, and relativenumber from ~/.vim/vimrc).
set -u
out=$1; shift
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
export LC_ALL=${LC_ALL:-C.UTF-8} PROBE_OUT=$out
vimbin=${VIMBIN:-vim}
files=()
for f in "$@"; do
  case $f in /*) files+=("$f") ;; *) files+=("$repo/$f") ;; esac
done
T() { timeout 5 tmux -L probe -f "$here/probe-tmux.conf" "$@"; }
rm -f "$out" "$out.screen"
T kill-server 2>/dev/null
cd ~ || exit 1
if [ "${vimbin##*/}" = vim.tiny ]; then
  T new-session -d -s p -x 200 -y 50 "$vimbin ${files[*]}"
  sleep 3
  T capture-pane -p -t p > "$out.screen"
  T send-keys -t p Escape ':qa!' Enter
  sleep 1
  if sed -n 2p "$out.screen" | grep -qE '^ +1 '; then
    echo "PASS vim.tiny read ~/.vim/vimrc (relativenumber)" > "$out"
  else
    echo "FAIL vim.tiny did not read ~/.vim/vimrc (no relativenumber)" > "$out"
  fi
  echo DONE >> "$out"
else
  T new-session -d -s p -x 200 -y 50 "$vimbin -c 'source $here/probe.vim' ${files[*]}"
  for _ in $(seq 1 240); do
    grep -qs '^DONE' "$out" && break
    T capture-pane -p -t p > "$out.screen" 2>/dev/null
    sleep 0.5
  done
  T capture-pane -p -t p > "$out.screen" 2>/dev/null
fi
T kill-server 2>/dev/null
"$here/check-report.sh" "$out"
```

- [ ] **Step 6: Write `tests/check-report.sh`**

```bash
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
```

- [ ] **Step 7: Write the samples**

`tests/samples/sample.py`:
```python
def greet(name):
    return "hello " + name


print(greet("world"))
```

`tests/samples/sample.yaml` (the trailing spaces on line 2 are the lint error ALE must find):
```yaml
key: value
other: value   
list:
  - one
```

`tests/samples/sample.json`:
```json
{"name": "probe", "list": [1, 2]}
```

`tests/samples/sample.sh`:
```sh
#!/bin/sh
echo "hello"
```

`tests/samples/sample.md`:
```markdown
# Title

Some `code` and **bold**.
```

`tests/samples/make-git-repo.sh`:
```sh
#!/bin/sh
# Creates a throwaway git repo in DIR with one committed file f.txt
# (commit "add-f" by "Probe"). Usage: make-git-repo.sh DIR
set -e
rm -rf "$1" && mkdir -p "$1" && cd "$1"
git init -q
printf 'x\n' > f.txt
git add f.txt
git -c user.name=Probe -c user.email=probe@example.com commit -q -m add-f
```

`tests/samples/ansible/ansible.cfg`:
```ini
[defaults]
roles_path = roles
```

`tests/samples/ansible/playbooks/site.yml` (line numbers matter to Task 7):
```yaml
- hosts: all
  roles:
    - web
  tasks:
    - name: extra
      ansible.builtin.include_role:
        name: web
        tasks_from: extra
```

`tests/samples/ansible/roles/web/tasks/main.yml`:
```yaml
- name: main task
  ansible.builtin.debug:
    msg: main
```

`tests/samples/ansible/roles/web/tasks/extra.yml`:
```yaml
- name: extra task
  ansible.builtin.debug:
    msg: extra
```

- [ ] **Step 8: Write the first failing expectation, `tests/expect/00-startup.vim`**

```vim
" Startup: the config loaded, at the expected tier, with a state dir and leader.
call Expect('eval', "exists('g:myvim_tier')", 1)
if !empty($PROBE_TIER)
  call Expect('eval', "get(g:, 'myvim_tier', -1)", str2nr($PROBE_TIER))
endif
call Expect('eval', "isdirectory(get(g:, 'myvim_state', '/nonexistent') . '/undo')", 1)
call Expect('eval', "get(g:, 'mapleader', '')", ' ')
```

- [ ] **Step 9: Write `tests/run-matrix.sh`**

```bash
#!/bin/bash
# Runs the test cases on the server VM and prints PASS/FAIL per case plus the
# problems. Usage: tests/run-matrix.sh [CASE...]   (default: all cases)
#   tools          vim 9.1 with the LSP servers, linters and fzf in /opt/myvim-tools
#   tools-ansible  same, first file an Ansible role (ansiblels only, not yamlls)
#   bare           vim 9.1 without those tools (old apt fzf only)
#   readonly       bare, with the repo read-only (state dir falls back)
#   rocky8 rocky9 ubuntu1604 centos7 tiny   Docker images from tests/docker/
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
tools=/opt/myvim-tools/bin:/opt/myvim-tools/node/bin
samples="tests/samples/sample.py tests/samples/sample.yaml tests/samples/sample.sh tests/samples/sample.md"
cases=${*:-tools tools-ansible bare readonly rocky8 rocky9 ubuntu1604 centos7 tiny}
failed=0
for c in $cases; do
  out=/tmp/myvim-probe/$c/report
  mkdir -p "$(dirname "$out")"
  case $c in
    tools)         PROBE_TIER=2 PATH=$tools:$PATH "$here/run-probe.sh" "$out" $samples ;;
    tools-ansible) PROBE_TIER=2 PATH=$tools:$PATH "$here/run-probe.sh" "$out" tests/samples/ansible/roles/web/tasks/main.yml ;;
    bare)          PROBE_TIER=2 "$here/run-probe.sh" "$out" $samples ;;
    readonly)      chmod -R a-w "$repo"; PROBE_TIER=2 "$here/run-probe.sh" "$out" $samples; chmod -R u+w "$repo" ;;
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
```

- [ ] **Step 10: Write `tests/push.sh`**

```bash
#!/bin/bash
# Copies this working tree to HOST:~/my-vim (replacing it, .state included)
# and installs it. Usage: tests/push.sh user@host
set -euo pipefail
host=$1
cd "$(dirname "$0")/.."
tar --exclude=.git --exclude=.state -cf - . |
  ssh "$host" 'rm -rf ~/my-vim.new && mkdir -p ~/my-vim.new && tar -x -C ~/my-vim.new && chmod -R u+w ~/my-vim 2>/dev/null; rm -rf ~/my-vim && mv ~/my-vim.new ~/my-vim'
ssh "$host" 'if [ -f ~/my-vim/install.sh ]; then LC_ALL=C.UTF-8 sh ~/my-vim/install.sh >/dev/null; else ln -sfn ~/my-vim ~/.vim; fi'
```

- [ ] **Step 11: Write the Docker images and scripts**

`tests/docker/rocky8.Dockerfile`:
```dockerfile
# vim 8.0.1763, tmux 2.7 (RHEL 8)
FROM rockylinux:8
RUN dnf -y install vim-enhanced tmux git && dnf clean all
```

`tests/docker/rocky9.Dockerfile`:
```dockerfile
# vim 8.2.2637, tmux 3.2a (RHEL 9)
FROM rockylinux:9
RUN dnf -y install vim-enhanced tmux git && dnf clean all
```

`tests/docker/ubuntu1604.Dockerfile`:
```dockerfile
# vim 7.4.1689: has packages, no TextYankPost, no timers in some builds
FROM ubuntu:16.04
RUN apt-get update && apt-get install -y vim tmux git && rm -rf /var/lib/apt/lists/*
```

`tests/docker/centos7.Dockerfile`:
```dockerfile
# vim 7.4.629: no packages (tier 0 + own plugin/ files only), tmux 1.8
FROM centos:7
RUN sed -i -e 's/^mirrorlist/#mirrorlist/' -e 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' /etc/yum.repos.d/CentOS-*.repo \
 && yum -y install vim-enhanced tmux git && yum clean all
ENV LC_ALL=en_US.UTF-8
```

`tests/docker/tiny.Dockerfile`:
```dockerfile
# vim-tiny only (no +eval)
FROM debian:12
RUN apt-get update && apt-get install -y --no-install-recommends vim-tiny tmux && rm -rf /var/lib/apt/lists/*
```

`tests/docker/build.sh`:
```bash
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
```

`tests/docker/run.sh`:
```bash
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
```

- [ ] **Step 12: Write the VM setup scripts**

`tests/vm/setup-server.sh`:
```bash
#!/bin/bash
# One-time setup of the server test VM (Ubuntu 24.04 with Docker). Needs sudo
# and internet. Run there: bash ~/my-vim/tests/vm/setup-server.sh
# Puts every optional tool under /opt/myvim-tools so run-matrix.sh can turn
# them on (case "tools") and off (case "bare") with PATH. Expects my-tmux in
# ~/projects/my-tmux (copied there by the dev machine).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
sudo apt-get update -q
sudo apt-get install -yq vim tmux mosh git fzf python3-venv curl xz-utils
T=/opt/myvim-tools
sudo mkdir -p $T/bin && sudo chown -R "$(id -u):$(id -g)" $T
node=$(curl -fsSL https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt | awk '/linux-x64\.tar\.xz$/ {print $2}')
curl -fsSL "https://nodejs.org/dist/latest-v22.x/$node" | tar -xJ -C $T
ln -sfn "$T/${node%.tar.xz}" $T/node
ln -sf $T/node/bin/node $T/bin/node
PATH=$T/bin:$T/node/bin:$PATH npm install -g --prefix $T pyright yaml-language-server bash-language-server \
  @ansible/ansible-language-server typescript typescript-language-server vscode-langservers-extracted prettier eslint_d
python3 -m venv $T/venv
$T/venv/bin/pip install -q yamllint pylint ansible-lint black isort
for b in $T/venv/bin/yamllint $T/venv/bin/pylint $T/venv/bin/ansible* $T/venv/bin/black $T/venv/bin/isort; do
  ln -sf "$b" $T/bin/
done
curl -fsSL https://github.com/junegunn/fzf/releases/download/v0.74.4/fzf-0.74.4-linux_amd64.tar.gz | tar -xz -C $T/bin fzf
curl -fsSL https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz | tar -xz -C /tmp
cp /tmp/ripgrep-14.1.1-x86_64-unknown-linux-musl/rg $T/bin/
curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v0.10.0/shellcheck-v0.10.0.linux.x86_64.tar.xz | tar -xJ -C /tmp
cp /tmp/shellcheck-v0.10.0/shellcheck $T/bin/
(cd ~/projects/my-tmux && ./install.sh)
bash ~/my-vim/tests/docker/build.sh
echo "server setup done"
```

`tests/vm/setup-client.sh`:
```bash
#!/bin/bash
# One-time setup of the client test VM (Ubuntu 24.04): tmux, mosh, my-tmux
# (copied to ~/projects/my-tmux by the dev machine) and an ssh key whose
# public half goes into the server's authorized_keys.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
sudo apt-get update -q
sudo apt-get install -yq tmux mosh python3
(cd ~/projects/my-tmux && ./install.sh)
[ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```

- [ ] **Step 13: Create the two VMs** (dev machine; homelab rules in `~/projects/vibe-powercli/.claude/CLAUDE.md`)

```bash
cd ~/projects/vibe-images
cat > "$TMPDIR/myvim-userdata.yaml" <<EOF
#cloud-config
users:
  - default
  - name: claude
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [docker]
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_ed25519.pub)
EOF
pwsh -NoProfile -File scripts/new-vm.ps1 -Name my-vim-test01 -Image docker-host -UserDataFile "$TMPDIR/myvim-userdata.yaml"
pwsh -NoProfile -File scripts/new-vm.ps1 -Name my-vim-client01 -Image ubuntu-2404-base -UserDataFile "$TMPDIR/myvim-userdata.yaml"
```
(`$TMPDIR` = the session scratchpad.) Each run prints the VM's IP. Write them to the git-ignored file:
```bash
cd ~/projects/my-vim && printf 'server=<server ip>\nclient=<client ip>\n' > .claude/vms.local
```
Expected: `ssh claude@<ip> true` works for both (accept the host keys once).

- [ ] **Step 14: Set the VMs up**

```bash
cd ~/projects/my-vim
SRV=$(sed -n 's/^server=//p' .claude/vms.local); CLI=$(sed -n 's/^client=//p' .claude/vms.local)
for h in $SRV $CLI; do
  git -C ~/projects/my-tmux archive --prefix=my-tmux/ HEAD | ssh claude@$h 'mkdir -p ~/projects && tar -x -C ~/projects'
done
chmod +x tests/*.sh tests/docker/*.sh tests/vm/*.sh tests/samples/*.sh
tests/push.sh claude@$SRV
ssh claude@$SRV 'bash ~/my-vim/tests/vm/setup-server.sh'
scp tests/vm/setup-client.sh claude@$CLI: && ssh claude@$CLI 'bash ~/setup-client.sh' | tail -1 > "$TMPDIR/client.pub"
ssh claude@$SRV "cat >> ~/.ssh/authorized_keys" < "$TMPDIR/client.pub"
ssh claude@$CLI "ssh -o StrictHostKeyChecking=accept-new claude@$SRV true" && echo client-to-server-ok
```
Expected: `server setup done`, five images in `ssh claude@$SRV docker images myvim-test`, `client-to-server-ok`.

- [ ] **Step 15: Snapshot both VMs** (powered off, no memory, per vibe-powercli rules), names `base-harness`:

```bash
pwsh -NoProfile -Command '. ~/projects/vibe-powercli/scripts/vc-connect.ps1; foreach ($n in "my-vim-test01","my-vim-client01") { $vm = Get-VM $n; Stop-VMGuest $vm -Confirm:$false | Out-Null; while ((Get-VM $n).PowerState -ne "PoweredOff") { Start-Sleep 5 }; New-Snapshot -VM $vm -Name base-harness -Memory:$false | Out-Null; Start-VM $vm | Out-Null }'
```

- [ ] **Step 16: Run the matrix and see it fail correctly**

Run: `tests/push.sh claude@$SRV && ssh claude@$SRV 'bash ~/my-vim/tests/run-matrix.sh'`
Expected: every case except `tiny` is `FAIL` with `FAIL exists('g:myvim_tier') (got 0, want 1)` (there is no vimrc yet); `tiny` is `FAIL` with `vim.tiny did not read ~/.vim/vimrc`. A case that says `no DONE` instead means the harness itself is broken: fix that before going on.

- [ ] **Step 17: Ship** (Ship procedure; branch `task-01-harness`, message `Add the VM/Docker test harness and probe`). PR body: the matrix output from Step 16 (failures are expected at this point).

---

### Task 2: vimrc skeleton (tiers, state dir, plugin table)

**Files:**
- Create: `vimrc`
- Modify: `tests/expect/00-startup.vim` (append)

**Interfaces:**
- Produces globals used everywhere: `g:myvim_root` (repo path, symlinks resolved), `g:myvim_state` (state dir or `''`), `g:myvim_tier` (0/1/2), `g:myvim_fzf` (0/1), `g:myvim_fzf_min` (`'0.63'`), `g:myvim_plugins` (list of `packadd!`ed names), `mapleader` = `' '`.
- Produces: `s:want` plugin table in `vimrc`; later tasks only edit conditions in it.

- [ ] **Step 1: Branch** `git fetch origin && git checkout -b task-02-vimrc origin/main`

- [ ] **Step 2: Append the failing expectations to `tests/expect/00-startup.vim`**

```vim
call Expect('eval', '&tabstop', 2)
call Expect('eval', '&relativenumber', 1)
call Expect('eval', "get(g:, 'myvim_fzf_min', '')", '0.63')
call Expect('eval', "type(get(g:, 'myvim_plugins', 0))", type([]))
call Expect('1', "exists('g:did_load_filetypes')", 1)
call Expect('1', "exists('g:syntax_on')", 1)
" the readonly case: the state dir must fall back outside the repo
if filewritable(get(g:, 'myvim_root', '/') . '/vimrc') != 1
  call Expect('eval', "stridx(get(g:, 'myvim_state', ''), '/.local/state/my-vim') > 0", 1)
endif
```

- [ ] **Step 3: Run, expect failure**

Run: `tests/push.sh claude@$SRV && ssh claude@$SRV 'bash ~/my-vim/tests/run-matrix.sh bare readonly tiny'`
Expected: FAIL on `exists('g:myvim_tier')` and the new checks.

- [ ] **Step 4: Write `vimrc`**

```vim
" my-vim: ~/.vim/vimrc (the repo is ~/.vim). Tiers are in README.md.
"
" Tier 0: vim-tiny (no +eval) reads only these plain `set` lines. Keep them
" to options every build has; everything else goes inside `if 1`, which
" builds without +eval skip.
set nocompatible
set number relativenumber
set tabstop=2 shiftwidth=2 expandtab autoindent
set ignorecase smartcase
set backspace=indent,eol,start
set splitright splitbelow
set scrolloff=999
set incsearch hlsearch
set laststatus=2 ruler showcmd
set wrap

if 1
  if &encoding !=# 'utf-8'
    set encoding=utf-8
  endif
  let g:myvim_root = fnamemodify(resolve(expand('<sfile>:p')), ':h')

  " Started with `vim -u <repo>/vimrc` instead of through the ~/.vim link:
  " add the repo to the paths ourselves (only then, or plugin/ loads twice)
  if resolve(expand('~/.vim')) !=# g:myvim_root
    let &runtimepath = g:myvim_root . ',' . &runtimepath . ',' . g:myvim_root . '/after'
    if exists('+packpath')
      let &packpath = g:myvim_root . ',' . &packpath
    endif
  endif

  " State (undo, swap, backup, viminfo, harpoon): in the repo's .state, or
  " ~/.local/state/my-vim when the repo isn't writable; '' if neither works
  function! s:state_dir() abort
    let base = empty($XDG_STATE_HOME) ? $HOME . '/.local/state' : $XDG_STATE_HOME
    for dir in [g:myvim_root . '/.state', base . '/my-vim']
      silent! call mkdir(dir . '/undo', 'p', 0700)
      if filewritable(dir . '/undo') == 2
        for sub in ['swap', 'backup', 'harpoon']
          silent! call mkdir(dir . '/' . sub, 'p', 0700)
        endfor
        return dir
      endif
    endfor
    return ''
  endfunction
  let g:myvim_state = s:state_dir()

  " 0: vim with +eval but no packages (7.4 before 7.4.1384): own plugin/ only
  " 1: packages (vim 8.0+): vendored plugins
  " 2: also jobs, timers, lambdas and 8.2: vim-lsp, asyncomplete, ALE
  let g:myvim_tier = has('packages') ? 1 : 0
  if g:myvim_tier && v:version >= 802 && has('job') && has('timers') && has('lambda')
    let g:myvim_tier = 2
  endif

  let mapleader = ' '

  " fzf.vim needs a recent fzf binary (s:min_version in fzf.vim's
  " autoload/fzf/vim.vim); older ones get ctrlp instead
  let g:myvim_fzf_min = '0.63'
  function! s:fzf_ok() abort
    if g:myvim_tier < 1 || !executable('fzf')
      return 0
    endif
    let v = matchlist(system('fzf --version'), '^\(\d\+\)\.\(\d\+\)')
    let m = split(g:myvim_fzf_min, '\.')
    return !empty(v) && (str2nr(v[1]) > str2nr(m[0]) || (str2nr(v[1]) == str2nr(m[0]) && str2nr(v[2]) >= str2nr(m[1])))
  endfunction
  let g:myvim_fzf = s:fzf_ok()

  " Vendored plugins (pack/vendor/opt, pinned in plugins.list) and when each
  " loads. A plugin that breaks an old vim gets a version condition here.
  let g:myvim_plugins = []
  let s:t2 = g:myvim_tier >= 2
  let s:want = [
    \ ['vim-nightfly-colors', 1], ['vim-fugitive', 1], ['vim-surround', 1],
    \ ['vim-commentary', 1], ['vim-repeat', 1], ['ReplaceWithRegister', 1],
    \ ['vim-tmux-navigator', 1], ['undotree', 1], ['vim-maximizer', 1],
    \ ['nerdtree', 1], ['vim-gitgutter', 1], ['lightline.vim', 1],
    \ ['auto-pairs', 1], ['indentLine', 1], ['ctrlp.vim', 1], ['vista.vim', 1],
    \ ['fzf', g:myvim_fzf], ['fzf.vim', g:myvim_fzf],
    \ ['vim-lsp', s:t2], ['asyncomplete.vim', s:t2], ['asyncomplete-lsp.vim', s:t2],
    \ ['asyncomplete-buffer.vim', s:t2], ['asyncomplete-file.vim', s:t2], ['ale', s:t2],
    \ ]
  if g:myvim_tier >= 1
    for [s:name, s:ok] in s:want
      if s:ok && isdirectory(g:myvim_root . '/pack/vendor/opt/' . s:name)
        execute 'packadd!' s:name
        call add(g:myvim_plugins, s:name)
      endif
    endfor
    unlet s:name s:ok
  endif
  unlet s:want s:t2

  filetype plugin indent on
  syntax on
endif
```

- [ ] **Step 5: Run, expect pass**

Run: `tests/push.sh claude@$SRV && ssh claude@$SRV 'bash ~/my-vim/tests/run-matrix.sh'`
Expected: every case `PASS` (tiny passes now: relativenumber comes from tier 0). centos7 passes `myvim_tier == 0`; its `'1'` checks are SKIP.

- [ ] **Step 6: Ship** (branch `task-02-vimrc`, message `Add vimrc: tiers, state dir, plugin table`).

---

### Task 3: Options, terminal escapes and window autocmds

**Files:**
- Create: `plugin/options.vim`, `autoload/myvim/window.vim`
- Create: `tests/expect/10-options.vim`

**Interfaces:**
- Produces: `myvim#window#preview_right()`, `myvim#window#help_height()`.

- [ ] **Step 1: Branch** `task-03-options`.

- [ ] **Step 2: Write the failing `tests/expect/10-options.vim`**

```vim
" my-nvim core/options.lua + nvim defaults + tmux escapes
call Expect('eval', '&shiftwidth', 2)
call Expect('eval', '&expandtab', 1)
call Expect('eval', '&cursorline', 1)
call Expect('eval', '&undofile', has('persistent_undo') ? 1 : 0)
call Expect('eval', "&undodir =~# '/undo'", 1)
call Expect('eval', "&directory =~# '/swap//'", 1)
call Expect('eval', "&iskeyword =~# '-'", 1)
call Expect('eval', '&title', 1)
call Expect('eval', '&hidden', 1)
call Expect('eval', '&autoread', 1)
call Expect('eval', '&ttimeoutlen', 50)
call Expect('eval', '&updatetime', 300)
call Expect('eval', '&mouse', 'nvi')
call Expect('eval', '&foldlevelstart', 99)
call Expect('eval', '&foldmethod', 'indent')
call Expect('eval', "&viminfo =~# 'n.*viminfo'", 1)
call Expect('eval', '&nrformats', 'bin,hex')
call Expect('eval', "exists('+signcolumn') ? &signcolumn : ''", exists('+signcolumn') ? 'auto' : '')
call Expect('eval', "exists('+termguicolors') ? &termguicolors : 0", exists('+termguicolors') && &t_Co >= 256 ? 1 : 0)
call Expect('eval', '&t_SI', "\e[6 q")
call Expect('eval', '&t_EI', "\e[2 q")
" run-probe's tmux has TERM=screen-256color: the escapes vim only sets for xterm
call Expect('eval', '&t_BE', "\e[?2004h")
call Expect('eval', "exists('&t_8f') ? &t_8f : ''", exists('+termguicolors') ? "\e[38;2;%lu;%lu;%lum" : '')
call Expect('eval', 'exists("&t_fe") ? &t_fe : "none"', exists('&t_fe') ? "\e[?1004h" : 'none')
call Scenario('eval', 'help window gets a third of its height', [], 'let g:probe_h = winheight(0) | help help', '', 'winheight(0) <= g:probe_h / 2', 1)
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh bare rocky8 centos7`): FAIL on the new checks.

- [ ] **Step 4: Write `plugin/options.vim`**

```vim
" Options from my-nvim's core/options.lua, the defaults nvim has and vim
" doesn't, and the terminal escapes vim only sets for $TERM=xterm* (inside
" tmux, $TERM is screen*/tmux*). Tier-0 options are in vimrc.
if !exists('g:myvim_tier') | finish | endif

set cursorline
set title
set iskeyword+=-
set hidden autoread
set ttimeout ttimeoutlen=50
set updatetime=300
set history=10000
set display=lastline
set nrformats=bin,hex
set nostartofline
set smarttab
set formatoptions=tcqj
set nojoinspaces
set wildmenu
set belloff=all
set mouse=nvi
if has('mouse_sgr')
  set ttymouse=sgr
endif
if exists('+signcolumn')
  set signcolumn=auto
endif
set background=dark
let &previewheight = &lines * 10 / 37

" folding (my-nvim: nvim-ufo, everything open)
set foldmethod=indent foldlevel=99 foldlevelstart=99 foldenable

" grep: ripgrep when there is one
if executable('rg')
  let &grepprg = 'rg --vimgrep --smart-case $*'
  set grepformat=%f:%l:%c:%m
else
  let &grepprg = 'grep -rnI --exclude-dir=.git $* .'
endif

" undo, swap, backup and viminfo in the state dir (see vimrc)
if !empty(g:myvim_state)
  if has('persistent_undo')
    set undofile
    let &undodir = g:myvim_state . '/undo//'
  endif
  let &directory = g:myvim_state . '/swap//'
  let &backupdir = g:myvim_state . '/backup' . (has('patch-8.1.0251') ? '//' : '')
  execute 'set viminfo+=n' . fnameescape(g:myvim_state . '/viminfo')
endif

" colours: true colour on 256-colour terminals (not the Linux console)
if exists('+termguicolors') && &t_Co >= 256
  set termguicolors
endif

if !has('gui_running')
  " nvim's cursor: block in normal, bar in insert, underline in replace
  let &t_SI = "\e[6 q"
  let &t_SR = "\e[4 q"
  let &t_EI = "\e[2 q"
  if $TERM =~# '^\%(screen\|tmux\)'
    let &t_8f = "\e[38;2;%lu;%lu;%lum"
    let &t_8b = "\e[48;2;%lu;%lu;%lum"
    " bracketed paste: a terminal paste into insert mode doesn't auto-indent each line
    let &t_BE = "\e[?2004h"
    let &t_BD = "\e[?2004l"
    exec "set t_PS=\e[200~"
    exec "set t_PE=\e[201~"
    " focus events, for autoread and gitgutter when switching tmux panes
    if exists('&t_fe')
      let &t_fe = "\e[?1004h"
      let &t_fd = "\e[?1004l"
      exec "set <FocusGained>=\e[I"
      exec "set <FocusLost>=\e[O"
    endif
  endif
endif

augroup myvim_options
  autocmd!
  autocmd BufWinEnter *.txt if &filetype ==# 'help' | call myvim#window#help_height() | endif
  autocmd WinEnter * if &previewwindow | call myvim#window#preview_right() | endif
augroup END
```

- [ ] **Step 5: Write `autoload/myvim/window.vim`** (more functions arrive in Tasks 5)

```vim
" Window helpers (my-nvim core/options.lua, core/keymaps.lua, core/scripts.lua)

" Help windows take a third of the height they open with
function! myvim#window#help_height() abort
  execute 'resize' max([winheight(0) / 3, 5])
endfunction

" Move the preview window to the far right unless it already is rightmost
function! myvim#window#preview_right() abort
  if !exists('*win_screenpos')
    return
  endif
  let col = win_screenpos(0)[1]
  for w in range(1, winnr('$'))
    if w != winnr() && win_screenpos(w)[1] > col
      wincmd L
      return
    endif
  endfor
endfunction
```

- [ ] **Step 6: Run, expect pass** (`run-matrix.sh`, all cases). If `&t_8f` fails on a container whose vim lacks `+termguicolors`, the Expect already accounts for it; any other FAIL is a real bug.

- [ ] **Step 7: Ship** (branch `task-03-options`, message `Port options, terminal escapes and window autocmds`).

---

### Task 4: Core keymaps and Alt keys

**Files:**
- Create: `plugin/keymaps.vim`, `plugin/terminal-keys.vim`, `tests/keytest.sh`
- Create: `tests/expect/20-keymaps.vim`
- Modify: `autoload/myvim/window.vim` (append `pedit_vertical`)
- Modify: `tests/run-matrix.sh` (add case `keys`)

**Interfaces:**
- Consumes: `myvim#clip#copy(text)` from Task 6 for `<leader>yy*`. Until Task 6 lands, the mappings call it lazily (autoload), so they only fail when pressed; Task 6's tests cover them.
- Produces: `myvim#window#pedit_vertical()`.

- [ ] **Step 1: Branch** `task-04-keymaps`.

- [ ] **Step 2: Write the failing `tests/expect/20-keymaps.vim`**

```vim
" keymaps.lua + vimscript/keymaps.vim
for s:m in ['<Space>hn', '<Space>+', '<Space>-', '<Space>sv', '<Space>sh', '<Space>se', '<Space>sx',
      \ '<Space>to', '<Space>tx', '<Space>tn', '<Space>tp', '<C-W>{{', '<Space>o', '<Space>O',
      \ '<Space>hh', '<C-c>', '<Space>yyr', '<Space>yyp', '<Space>yyf', '<M-,>', '<M-.>', 'Y', 'x', 'dd']
  call ExpectMap('eval', 'n', s:m)
endfor
for s:n in range(1, 9)
  call ExpectMap('eval', 'n', '<Space>' . s:n)
endfor
call ExpectMap('eval', 'i', 'jk')
call ExpectMap('eval', 'x', '<C-r>')
call ExpectMap('eval', 'x', '<C-e>')
call ExpectMap('eval', 'x', '<CR>')
unlet s:m s:n
call Scenario('eval', 'x does not touch the unnamed register', ['abc'], 'let @" = "keep"', 'x', '[getline(1), @"]', ['bc', 'keep'])
call Scenario('eval', 'dd goes to register 9', ['one', 'two'], '', 'dd', '@9', "one\n")
call Scenario('eval', 'jk leaves insert mode', ['ab'], '', 'ixjk', '[getline(1), mode()]', ['xab', 'n'])
call Scenario('eval', '<leader>o adds a line below', ['a'], '', "\<Space>o", 'getline(1, "$")', ['a', ''])
call Scenario('eval', '<leader>hh highlights the word, cursor stays', ['foo bar foo'], '', "w\<Space>hh", '[@/, col(".")]', ['\<bar\>', 5])
call Scenario('eval', 'visual <CR> searches the selection via register h', ['a.b a.b'], 'let @" = "keep"', "v2l\<CR>", '[@/, @"]', ['\Va.b', 'keep'])
call Scenario('eval', '<leader>+ increments', ['x 41'], '', "\<Space>+", 'getline(1)', 'x 42')
call Scenario('eval', 'Y yanks to the end of line', ['abc def'], '', 'wY', '@"', 'def')
call Scenario('eval', '<leader>2 goes to tab 2', [], 'tabnew | tabnew | tabfirst', "\<Space>2", 'tabpagenr()', 2)
" the tab scenario leaves tabs behind
silent! tabonly
```
(Real Alt-key presses are checked by `tests/keytest.sh` below; `:normal` can't send a terminal's Esc+key.)

- [ ] **Step 3: Write `tests/keytest.sh`** (real key presses through tmux: Alt keys, `jk` timing)

```bash
#!/bin/bash
# Presses real keys in vim inside a private tmux and checks the result.
# Usage: tests/keytest.sh   (exit 1 on failure)
set -u
here=$(cd "$(dirname "$0")" && pwd)
T() { timeout 5 tmux -L keys -f "$here/probe-tmux.conf" "$@"; }
out=/tmp/myvim-keytest; rm -f $out.*
T kill-server 2>/dev/null
printf 'one\ntwo\n' > $out.txt
T new-session -d -s k -x 160 -y 40 "vim $out.txt"
sleep 2
w() { T send-keys -t k Escape ":call writefile([$1], '$out.$2')" Enter; sleep 0.5; }
T send-keys -t k ':vsplit' Enter; sleep 0.5
w 'winwidth(0)' w1
T send-keys -t k M-.; sleep 0.5
w 'winwidth(0)' w2
T send-keys -t k i x j k; sleep 0.5          # jk typed at human speed (> ttimeoutlen apart)
w 'mode() . getline(1)' m
T send-keys -t k Escape ':qa!' Enter; sleep 0.5
T kill-server 2>/dev/null
fail=0
[ "$(cat $out.w2)" -eq $(( $(cat $out.w1) + 2 )) ] && echo "PASS <M-.> widens by 2" || { echo "FAIL <M-.>: $(cat $out.w1) -> $(cat $out.w2)"; fail=1; }
[ "$(cat $out.m)" = nxone ] && echo "PASS jk leaves insert" || { echo "FAIL jk: $(cat $out.m)"; fail=1; }
exit $fail
```

Add the case to `tests/run-matrix.sh`: in the `case $c in` list add
```bash
    keys)          "$here/keytest.sh" ;;
```
and add `keys` to the default `cases=` list after `bare`.

- [ ] **Step 4: Run, expect failure** (`run-matrix.sh bare keys rocky8`).

- [ ] **Step 5: Write `plugin/keymaps.vim`**

```vim
" my-nvim core/keymaps.lua and vimscript/keymaps.vim. Plugin keymaps are in
" plugin/plugins.vim, LSP ones in plugin/lsp.vim.
if !exists('g:myvim_tier') | finish | endif

inoremap jk <Esc>
nnoremap <leader>hn :nohl<CR>
nnoremap Y y$

" x deletes without copying; dd keeps the line in register 9 only
nnoremap x "_x
nnoremap dd "9dd

nnoremap <leader>+ <C-a>
nnoremap <leader>- <C-x>

" splits
nnoremap <leader>sv <C-w>v
nnoremap <leader>sh <C-w>s
nnoremap <leader>se <C-w>=
nnoremap <leader>sx :close<CR>

" tabs
nnoremap <leader>to :tabnew<CR>
nnoremap <leader>tx :tabclose<CR>
nnoremap <leader>tn :tabn<CR>
nnoremap <leader>tp :tabp<CR>
for s:n in range(1, 9)
  execute 'noremap <leader>' . s:n . ' ' . s:n . 'gt'
endfor
unlet s:n

" preview window: open the tag under the cursor in a vertical split
nnoremap <silent> <C-W>{{ :call myvim#window#pedit_vertical()<CR>

" replace the selection (register h), with confirmation from the cursor on / without, whole file
xnoremap <C-r> "hy:.,$s/\C<C-r>h//gc<left><left><left>
xnoremap <C-e> "hy:%s/\C<C-r>h//g<left><left>

" blank lines without leaving normal mode
nnoremap <leader>o o<Esc>
nnoremap <leader>O O<Esc>

" highlight the word under the cursor without jumping
nnoremap <silent> <leader>hh :let @/='\<<C-R>=expand("<cword>")<CR>\>'<CR>:set hls<CR>
" highlight the visual selection (yanks into register h, not the clipboard)
xnoremap <silent> <CR> "hy:silent! let searchTerm = '\V'.substitute(escape(@h, '\/'), "\n", '\\n', "g") <bar> let @/ = searchTerm <bar> echo '/'.@/ <bar> call histadd("search", searchTerm) <bar> set hls<CR>
" Ctrl-C toggles hlsearch
nnoremap <silent> <C-c> :if (&hlsearch == 1) \| set nohlsearch \| else \| set hlsearch \| endif<CR>

" file path to the clipboard: relative, full, name
nnoremap <silent> <leader>yyr :call myvim#clip#copy(expand('%'))<CR>
nnoremap <silent> <leader>yyp :call myvim#clip#copy(expand('%:p'))<CR>
nnoremap <silent> <leader>yyf :call myvim#clip#copy(expand('%:t'))<CR>

" resize (not <M-h>: harpoon uses <M-h/j/k/l>)
nnoremap <M-,> :vertical resize -2<CR>
nnoremap <M-.> :vertical resize +2<CR>
```

- [ ] **Step 6: Write `plugin/terminal-keys.vim`**

```vim
" Alt keys in terminal vim arrive as Esc + key: tell vim they are <M-key>
" (resize <M-,>/<M-.>, harpoon <M-h/j/k/l/e/p/n>). ttimeoutlen=50 (options.vim)
" keeps a real Esc from waiting and leaves `jk` alone.
if !exists('g:myvim_tier') || has('gui_running') | finish | endif
for s:k in ['h', 'j', 'k', 'l', 'e', 'p', 'n', ',', '.']
  execute 'set <M-' . s:k . ">=\e" . s:k
endfor
unlet s:k
```

- [ ] **Step 7: Append to `autoload/myvim/window.vim`**

```vim
" <C-W>{{: the tag under the cursor in a preview window on the far right
function! myvim#window#pedit_vertical() abort
  let &previewheight = winwidth(0) * 2 / 5
  execute 'pedit +/' . escape(expand('<cword>'), ' \/')
  wincmd P
  wincmd L
endfunction
```

- [ ] **Step 8: Run, expect pass** (`run-matrix.sh`): all PASS, `keys` PASS. If `<M-.>` fails in `keys` only, check `T send-keys M-.` reaches vim as `Esc .` (`tmux show -g escape-time` must be ≤ 50).

- [ ] **Step 9: Ship** (branch `task-04-keymaps`, message `Port core keymaps and terminal Alt keys`).

---

### Task 5: Scripts (F5, preview scroll, inspect, swap prompt, clear undo)

**Files:**
- Create: `plugin/scripts.vim`, `autoload/myvim/scripts.vim`, `autoload/myvim/swap.vim`, `tests/swaptest.sh`
- Modify: `autoload/myvim/window.vim` (append `preview_scroll`, `inspect`)
- Create: `tests/expect/30-scripts.vim`
- Modify: `tests/run-matrix.sh` (case `swap`)

**Interfaces:**
- Produces: `myvim#scripts#toggle_number()`, `myvim#scripts#clear_undo()`, `myvim#window#preview_scroll(dir)`, `myvim#window#inspect()`, `myvim#swap#remember(buf, file, swap)`, `myvim#swap#ask(buf)`.

- [ ] **Step 1: Branch** `task-05-scripts`.

- [ ] **Step 2: Write the failing `tests/expect/30-scripts.vim`**

```vim
" core/scripts.lua
call ExpectMap('eval', 'n', '<F5>')
call ExpectMap('eval', 'n', '<C-P><C-D>')
call ExpectMap('eval', 'n', '<C-P><C-U>')
call ExpectMap('eval', 'n', '<Space>hi')
call ExpectMap('eval', 'n', 'uc')
call Expect('eval', "exists('#myvim_swap#SwapExists')", 1)
call Scenario('eval', 'F5 turns numbers off', ['a'], 'setlocal number relativenumber', "\<F5>", '[&l:number, &l:relativenumber]', [0, 0])
call Scenario('eval', 'F5 twice turns them back on', ['a'], 'setlocal number relativenumber', "\<F5>\<F5>", '[&l:number, &l:relativenumber]', [1, 1])
call Scenario('eval', 'uc clears the undo history', ['a'], '', "xuc", 'undotree().seq_last', 0)
call Scenario('eval', 'preview scroll without a preview window is quiet', ['a'], '', "\<C-P>\<C-D>", 'v:errmsg', '')
```
(`undotree()` exists from 7.4; `x` here is the `"_x` mapping, still an undoable change.)

- [ ] **Step 3: Write `tests/swaptest.sh`** (the swap prompt needs a real crash)

```bash
#!/bin/bash
# Leaves a swap file with unsaved changes, reopens the file, recovers, and
# checks vim asks to delete the swap. Usage: tests/swaptest.sh
set -u
here=$(cd "$(dirname "$0")" && pwd)
T() { timeout 5 tmux -L swap -f "$here/probe-tmux.conf" "$@"; }
f=/tmp/myvim-swaptest.txt; rm -f "$f"; printf 'saved\n' > "$f"
rm -f ~/.vim/.state/swap/*myvim-swaptest* ~/.local/state/my-vim/swap/*myvim-swaptest*
T kill-server 2>/dev/null
T new-session -d -s s -x 160 -y 40 "vim $f"; sleep 2
T send-keys -t s o unsaved Escape; sleep 1.5      # unsaved change, swap written (updatetime 300)
T kill-server; sleep 0.5                           # vim dies, swap stays
T new-session -d -s s -x 160 -y 40 "vim $f"; sleep 2
T send-keys -t s r; sleep 1                        # (R)ecover at the ATTENTION prompt
T send-keys -t s Enter; sleep 0.5
T send-keys -t s ':w' Enter; sleep 0.5             # recovered text saved: buffer unmodified
T send-keys -t s ":e" Enter; sleep 1
screen=$(T capture-pane -p -t s)
T kill-server 2>/dev/null
grep -q 'unsaved' "$f" && echo "PASS recovered" || { echo "FAIL recovery"; exit 1; }
echo "$screen" | grep -q 'Delete swap file? (y/N)' && echo "PASS asks to delete swap" || { echo "FAIL no prompt"; echo "$screen"; exit 1; }
```
Note: the prompt appears after `:e` re-reads the file while the old swap still exists (SwapExists fires again, recovery choice then leaves the buffer unmodified). If vim's ATTENTION prompt differs on this build, adjust the key presses, not the expectation.

Add to `tests/run-matrix.sh` case list: `    swap)          "$here/swaptest.sh" ;;` and `swap` to the default cases after `keys`.

- [ ] **Step 4: Run, expect failure** (`run-matrix.sh bare swap`).

- [ ] **Step 5: Write `plugin/scripts.vim`**

```vim
" my-nvim core/scripts.lua: number toggle, preview scrolling, highlight
" inspection, the swap-file prompt, and uc (undotree.lua) to clear undo.
if !exists('g:myvim_tier') | finish | endif

nnoremap <silent> <F5> :call myvim#scripts#toggle_number()<CR>
nnoremap <silent> <C-P><C-D> :call myvim#window#preview_scroll('down')<CR>
nnoremap <silent> <C-P><C-U> :call myvim#window#preview_scroll('up')<CR>
nnoremap <silent> <leader>hi :call myvim#window#inspect()<CR>
nnoremap <silent> uc :call myvim#scripts#clear_undo()<CR>

augroup myvim_swap
  autocmd!
  autocmd SwapExists * call myvim#swap#remember(str2nr(expand('<abuf>')), expand('<afile>:p'), v:swapname)
augroup END
```

- [ ] **Step 6: Write `autoload/myvim/scripts.vim`**

```vim
" F5: line numbers on/off
function! myvim#scripts#toggle_number() abort
  if &relativenumber
    setlocal norelativenumber nonumber
    echo 'Numbering off'
  else
    setlocal relativenumber number
    echo 'Numbering on'
  endif
endfunction

" uc: forget the undo history of the current buffer
function! myvim#scripts#clear_undo() abort
  let old = &undolevels
  setlocal undolevels=-1
  execute "normal! a \<BS>\<Esc>"
  let &l:undolevels = old
  echo 'Undo history cleared'
endfunction
```

- [ ] **Step 7: Write `autoload/myvim/swap.vim`**

```vim
" After vim's own swap-file dialog: when the recovered buffer is unchanged
" (nothing to recover), offer to delete the swap file (core/scripts.lua).
let s:pending = {}

function! myvim#swap#remember(buf, file, swap) abort
  let s:pending[a:buf] = a:swap
  augroup myvim_swap_ask
    execute 'autocmd! BufReadPost <buffer=' . a:buf . '>'
    execute 'autocmd BufReadPost <buffer=' . a:buf . '> call myvim#swap#ask(' . a:buf . ')'
  augroup END
endfunction

function! myvim#swap#ask(buf) abort
  execute 'autocmd! myvim_swap_ask BufReadPost <buffer=' . a:buf . '>'
  " after vim's recovery messages
  if has('timers')
    call timer_start(0, function('s:ask', [a:buf]))
  else
    call s:ask(a:buf)
  endif
endfunction

function! s:ask(buf, ...) abort
  let swap = get(s:pending, a:buf, '')
  silent! call remove(s:pending, a:buf)
  if empty(swap) || !filereadable(swap) || bufnr('%') != a:buf || &modified
    return
  endif
  if input('Delete swap file? (y/N) ') =~? '^y'
    echo delete(swap) == 0 ? 'Deleted swap: ' . swap : 'Failed to delete swap: ' . swap
  else
    echo 'Kept swap: ' . swap
  endif
endfunction
```

- [ ] **Step 8: Append to `autoload/myvim/window.vim`**

```vim
" <C-P><C-D> / <C-P><C-U>: scroll the preview window half a page from anywhere
function! myvim#window#preview_scroll(dir) abort
  for w in range(1, winnr('$'))
    if getwinvar(w, '&previewwindow')
      let cur = winnr()
      noautocmd execute w . 'wincmd w'
      execute 'normal!' (a:dir ==# 'down' ? "\<C-D>" : "\<C-U>")
      noautocmd execute cur . 'wincmd w'
      return
    endif
  endfor
  echo 'No preview window found'
endfunction

" <leader>hi: syntax groups under the cursor (nvim's :Inspect)
function! myvim#window#inspect() abort
  let [l, c] = [line('.'), col('.')]
  let stack = map(synstack(l, c), 'synIDattr(v:val, "name")')
  echo (empty(stack) ? '(no syntax)' : join(stack, ' > ')) . ' -> ' . synIDattr(synIDtrans(synID(l, c, 1)), 'name')
endfunction
```

- [ ] **Step 9: Run, expect pass** (`run-matrix.sh`; all PASS incl. `swap`).

- [ ] **Step 10: Ship** (branch `task-05-scripts`, message `Port core scripts: F5, preview scroll, inspect, swap prompt`).

---

### Task 6: Clipboard through tmux, ssh and mosh

The most important task. Spec section "Clipboard and tmux" is the contract.

**Files:**
- Create: `plugin/clipboard.vim`, `autoload/myvim/clip.vim`
- Create: `tests/expect/40-clipboard.vim`
- Create: `tests/cliptest/cliptest.py`, `tests/cliptest/outer.sh`, `tests/cliptest/remote.sh`

**Interfaces:**
- Produces: `g:myvim_clip_mode` (`system`/`tmux`/`osc52`/`none`), `myvim#clip#mode()`, `myvim#clip#copy(text)`, `myvim#clip#on_yank(event)`, `myvim#clip#put(key, count, reg, visual)`, `myvim#clip#messages()`, command `:MessagesToClipboard`.

- [ ] **Step 1: Branch** `task-06-clipboard`.

- [ ] **Step 2: Write the failing `tests/expect/40-clipboard.vim`**

run-probe.sh's vim runs in a private tmux, so `$TMUX` is set and the mode is `tmux`; `tmux` commands from vim reach that private server.

```vim
" Clipboard in tmux mode (run-probe's private tmux). The client side (OSC 52
" reaching the terminal) is tests/cliptest, run from the client VM.
call Expect('eval', "get(g:, 'myvim_clip_mode', '')", 'tmux')
call Expect('eval', "exists(':MessagesToClipboard')", 2)
call ExpectMap('tmux', 'n', 'p')
call ExpectMap('tmux', 'x', 'p')
call ExpectMap('tmux', 'n', 'P')
let s:buf = "system('tmux save-buffer -')"
let s:set = "call system('tmux set-buffer -- ' . shellescape(%s))"
call Scenario('yankpost', 'yy reaches the tmux buffer', ['clip-yank-1'], '', 'yy', s:buf, "clip-yank-1\n")
call Scenario('yankpost', 'yiw reaches the tmux buffer', ['word other'], '', 'yiw', s:buf, 'word')
call Scenario('yankpost', 'deletes reach it too (unnamedplus)', ['gone'], '', 'diw', s:buf, 'gone')
call Scenario('yankpost', 'yank into a named register does not', ['named'], printf(s:set, 'keep-1'), '"ayy', s:buf, 'keep-1')
call Scenario('tmux', 'x does not touch the tmux buffer', ['xyz'], printf(s:set, 'keep-2'), 'x', s:buf, 'keep-2')
call Scenario('tmux', 'p pastes the tmux buffer (another pane set it)', ['a'], printf(s:set, 'from-pane'), 'p', 'getline(1)', 'afrom-pane')
call Scenario('tmux', '3p pastes three times', ['a'], printf(s:set, 'z'), '3p', 'getline(1)', 'azzz')
call Scenario('tmux', '"ap pastes register a, not the tmux buffer', ['a'], 'let @a = "reg-a" | ' . printf(s:set, 'tmux-text'), '"ap', 'getline(1)', 'areg-a')
call Scenario('tmux', 'dd then p pastes the clipboard, as with unnamedplus', ['one', 'two'], printf(s:set, 'clip'), 'ddp', 'getline(1, "$")', ['tclipwo'])
call Scenario('yankpost', 'yy, dd, p pastes the yanked line', ['one', 'two'], '', 'yyjddp', 'getline(1, "$")', ['one', 'one'])
call Scenario('yankpost', 'a blockwise yank stays blockwise', ['ab', 'cd'], '', "\<C-v>jyP", 'getline(1, "$")', ['aab', 'ccd'])
call Scenario('tmux', 'visual p takes the tmux buffer', ['old'], printf(s:set, 'new'), 'viwp', 'getline(1)', 'new')
call Scenario('tmux', '<leader>yyf copies the file name', [], 'file /tmp/probe-name.txt', "\<Space>yyf", s:buf, 'probe-name.txt')
call Scenario('tmux', ':MessagesToClipboard copies :messages', [], 'unsilent echomsg "probe-msg-42"', ":MessagesToClipboard\<CR>", s:buf . " =~# 'probe-msg-42'", 1)
unlet s:buf s:set
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh bare rocky8 rocky9 ubuntu1604`).

- [ ] **Step 4: Write `autoload/myvim/clip.vim`**

```vim
" Clipboard for servers (spec: "Clipboard and tmux"). Like my-nvim's
" clipboard=unnamedplus with nvim's tmux provider:
"   tmux   yank -> tmux buffer + client clipboard; p -> tmux buffer first
"   osc52  yank -> OSC 52 straight to the terminal
"   system yank/paste through vim's own +clipboard

" what vim last sent: {'text', 'lines', 'type'}; p restores this exact
" register (blockwise stays blockwise) when the tmux buffer still holds it
let s:last = {'text': '', 'lines': [], 'type': 'v'}
let s:tmux32 = -1

function! myvim#clip#mode() abort
  if has('clipboard') && (has('mac') || has('macunix') || !empty($DISPLAY) || !empty($WAYLAND_DISPLAY))
    return 'system'
  elseif !empty($TMUX) && executable('tmux')
    return 'tmux'
  elseif !has('gui_running')
    return 'osc52'
  endif
  return 'none'
endfunction

" tmux 3.2+ has load-buffer -w and refresh-client -l
function! s:tmux32() abort
  if s:tmux32 < 0
    let v = matchlist(system('tmux -V'), '\(\d\+\)\.\(\d\+\)')
    let s:tmux32 = !empty(v) && (str2nr(v[1]) > 3 || (str2nr(v[1]) == 3 && str2nr(v[2]) >= 2))
  endif
  return s:tmux32
endfunction

function! s:osc52(text, passthrough) abort
  let seq = "\e]52;c;" . substitute(system('base64', a:text), '\n', '', 'g') . "\x07"
  if a:passthrough
    let seq = "\ePtmux;" . substitute(seq, "\e", "\e\e", 'g') . "\e\\"
  endif
  if exists('*echoraw')
    call echoraw(seq)
  elseif filewritable('/dev/tty')
    call writefile([seq], '/dev/tty', 'b')
  endif
endfunction

function! s:send(text) abort
  let mode = get(g:, 'myvim_clip_mode', 'none')
  if mode ==# 'system'
    call setreg('+', a:text)
  elseif mode ==# 'tmux'
    if s:tmux32()
      call system('tmux load-buffer -w -', a:text)
    else
      call system('tmux load-buffer -', a:text)
      call s:osc52(a:text, 1)
    endif
  elseif mode ==# 'osc52'
    call s:osc52(a:text, 0)
  endif
endfunction

" <leader>yy*, :MessagesToClipboard
function! myvim#clip#copy(text) abort
  let s:last = {'text': a:text, 'lines': split(a:text, "\n", 1), 'type': 'v'}
  call s:send(a:text)
endfunction

" TextYankPost: what unnamedplus copies, yanks and deletes into the unnamed register
function! myvim#clip#on_yank(event) abort
  if a:event.regname !=# '' && a:event.regname !=# '"'
    return
  endif
  let text = join(a:event.regcontents, "\n") . (a:event.regtype ==# 'V' ? "\n" : '')
  let s:last = {'text': text, 'lines': copy(a:event.regcontents), 'type': a:event.regtype}
  call s:send(text)
endfunction

" Set the unnamed register from the tmux buffer, asking the client terminal
" for its clipboard first (tmux 3.2+), like nvim's tmux provider
function! s:pull() abort
  if s:tmux32()
    call system('tmux refresh-client -l')
  endif
  let text = system('tmux save-buffer -')
  if v:shell_error || empty(text)
    return
  endif
  if text ==# s:last.text
    call setreg('"', s:last.lines, s:last.type)
    return
  endif
  let lines = split(text, "\n", 1)
  if text =~# "\n$"
    call remove(lines, -1)
    call setreg('"', lines, 'V')
  else
    call setreg('"', lines, 'v')
  endif
endfunction

" p P gp gP (normal and visual) in tmux mode
function! myvim#clip#put(key, count, reg, visual) abort
  if a:reg ==# '"'
    call s:pull()
  endif
  execute 'normal! ' . (a:visual ? 'gv' : '') . a:count . '"' . a:reg . a:key
endfunction

" :MessagesToClipboard (core/scripts.lua)
function! myvim#clip#messages() abort
  redir => msgs
  silent messages
  redir END
  call myvim#clip#copy(msgs)
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  call setline(1, split(msgs, "\n"))
  echo 'Messages copied to clipboard and opened in new buffer.'
endfunction
```

- [ ] **Step 5: Write `plugin/clipboard.vim`**

```vim
" Clipboard: see autoload/myvim/clip.vim and the spec's "Clipboard and tmux".
if !exists('g:myvim_tier') | finish | endif

let g:myvim_clip_mode = get(g:, 'myvim_clip_mode', myvim#clip#mode())
if g:myvim_clip_mode ==# 'system'
  set clipboard^=unnamedplus
elseif g:myvim_clip_mode !=# 'none'
  if exists('##TextYankPost')
    augroup myvim_clip
      autocmd!
      autocmd TextYankPost * call myvim#clip#on_yank(copy(v:event))
    augroup END
  endif
  if g:myvim_clip_mode ==# 'tmux'
    for s:k in ['p', 'P', 'gp', 'gP']
      execute 'nnoremap <silent> ' . s:k . ' :<C-u>call myvim#clip#put(' . string(s:k) . ', v:count1, v:register, 0)<CR>'
      execute 'xnoremap <silent> ' . s:k . ' :<C-u>call myvim#clip#put(' . string(s:k) . ', v:count1, v:register, 1)<CR>'
    endfor
    unlet s:k
  endif
endif

command! MessagesToClipboard call myvim#clip#messages()
```

- [ ] **Step 6: Run the probe matrix, expect pass** (`run-matrix.sh`). On `ubuntu1604` (no `TextYankPost`) the `yankpost` scenarios are SKIP and the `tmux` ones must still PASS. If only `centos7` fails the `tmux` scenarios because its tmux 1.8 can't `save-buffer -`/`load-buffer -`, make the probe's `'tmux'` condition also require `tmux -V` ≥ 2.0 (with a comment saying why), and note in the README that `p` reads the tmux buffer only with tmux 2.0+.

- [ ] **Step 7: Write `tests/cliptest/remote.sh`**

```bash
#!/bin/bash
# Server side of the clipboard chain test (tests/cliptest/cliptest.py).
#   remote.sh prepare TOKEN   write ~/t/yank.txt, kill any old "nv" session
#   remote.sh ready           exit 0 once session nv runs vim (leaves my-tmux's view mode first)
#   remote.sh run TOKEN       yank line 2, check the tmux buffer, paste with p, then
#                             paste a buffer "another pane" set, report RESULT lines
# TMUX_CMD runs tmux (default "tmux"; e.g. "tmux -L stock", "docker exec cliprocky8 tmux").
# RUN prefixes commands that must run where vim runs (e.g. "docker exec cliprocky8").
# T_HOME is the home vim sees (default $HOME).
export LC_ALL=C.UTF-8
TMUX_CMD=${TMUX_CMD:-tmux}
RUN=${RUN:-}
T_HOME=${T_HOME:-$HOME}
T() { timeout 5 $TMUX_CMD "$@"; }
R() { $RUN "$@"; }
case $1 in
prepare)
  T kill-session -t nv 2>/dev/null
  R sh -c "rm -f /tmp/prov /tmp/after-p.txt $T_HOME/.vim/.state/swap/*yank.txt.sw?; mkdir -p $T_HOME/t; printf 'first line\n%s\nlast line\n' '$2' > $T_HOME/t/yank.txt" ;;
ready)
  [ "$(T list-panes -t nv -F '#{pane_current_command}' 2>/dev/null)" = vim ] || exit 1
  for i in 1 2 3; do
    [ "$(T display -p -t nv '#{pane_in_mode}')" = 1 ] && T send-keys -t nv -X cancel
    sleep 0.3
  done
  [ "$(T display -p -t nv '#{pane_in_mode}')" = 0 ] ;;
run)
  TOKEN=$2
  T send-keys -t nv Escape ":call writefile(['mode=' . g:myvim_clip_mode, 'TMUX=' . \$TMUX, 'version=' . v:version], '/tmp/prov')" Enter; sleep 1
  echo "vim sees: $(R cat /tmp/prov 2>/dev/null | tr '\n' ' ')"
  T set-buffer -b marker before-yank
  T send-keys -t nv Escape g g j y y; sleep 2
  echo "tmux buffers after yy:"; T list-buffers -F '  #{buffer_name}: #{buffer_sample}'
  T list-buffers -F '#{buffer_sample}' | grep -q "$TOKEN" && echo "RESULT tmux-buffer: OK" || echo "RESULT tmux-buffer: MISSING"
  T send-keys -t nv G p; sleep 1
  T send-keys -t nv Escape ":w! /tmp/after-p.txt" Enter; sleep 1
  [ "$(R grep -c "$TOKEN" /tmp/after-p.txt 2>/dev/null)" -ge 2 ] && echo "RESULT paste-own: OK" || echo "RESULT paste-own: FAILED"
  T set-buffer -- "pane-$TOKEN"
  T send-keys -t nv G p; sleep 1
  T send-keys -t nv Escape ":w! /tmp/after-p.txt" Enter; sleep 1
  R grep -q "pane-$TOKEN" /tmp/after-p.txt && echo "RESULT paste-other-pane: OK" || echo "RESULT paste-other-pane: FAILED"
  echo "file after the pastes:"; R sed 's/^/  /' /tmp/after-p.txt
  T capture-pane -p -t nv | grep -iE 'Press ENTER|error|E[0-9]{3,4}:' | sed 's/^/  screen: /'
  T send-keys -t nv Escape ":qa!" Enter; sleep 1
  T kill-session -t nv 2>/dev/null ;;
esac
```

- [ ] **Step 8: Write `tests/cliptest/outer.sh`** (from my-nvim's `.claude/cliptest/outer.sh`, unchanged)

```bash
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
```

- [ ] **Step 9: Write `tests/cliptest/cliptest.py`**

```python
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
```

- [ ] **Step 10: Run the eight chains from the client VM**

```bash
SRV=$(sed -n 's/^server=//p' .claude/vms.local); CLI=$(sed -n 's/^client=//p' .claude/vms.local)
tests/push.sh claude@$SRV
ssh claude@$SRV 'docker rm -f cliprocky8 >/dev/null 2>&1; docker run -d --name cliprocky8 -v ~/my-vim:/src:ro myvim-test:rocky8 sleep infinity && docker exec cliprocky8 bash -c "cp -r /src ~/my-vim && (sh ~/my-vim/install.sh >/dev/null 2>&1 || ln -sfn ~/my-vim ~/.vim)"'
scp -r tests/cliptest claude@$CLI:
S=claude@$SRV
ssh claude@$CLI "cd cliptest && \
python3 cliptest.py c1-ssh-tmux $S 'ssh -t $S tmux new -s nv vim ~/t/yank.txt'; \
python3 cliptest.py c2-mosh-tmux $S 'mosh $S -- tmux new -s nv vim t/yank.txt'; \
LOCAL_CHECK='tmux -L outer list-buffers -F \"#{buffer_sample}\"' python3 cliptest.py c3-tmux-ssh-tmux $S \"bash outer.sh 'ssh -t $S tmux new -s nv vim ~/t/yank.txt'\"; \
LOCAL_CHECK='tmux -L outer list-buffers -F \"#{buffer_sample}\"' python3 cliptest.py c4-tmux-mosh-tmux $S \"bash outer.sh 'mosh $S -- tmux new -s nv vim t/yank.txt'\"; \
DRIVE=stdin python3 cliptest.py c5-ssh-notmux $S 'ssh -t $S vim ~/t/yank.txt'; \
python3 cliptest.py c6-lost-TMUX $S 'ssh -t $S tmux new -s nv env -u TMUX vim ~/t/yank.txt'; \
REMOTE_ENV='TMUX_CMD=\"tmux -L stock\"' python3 cliptest.py c7-stock-tmux $S 'ssh -t $S tmux -L stock -f /dev/null new -s nv vim ~/t/yank.txt'; \
REMOTE_ENV='TMUX_CMD=\"docker exec cliprocky8 tmux\" RUN=\"docker exec cliprocky8\" T_HOME=/root' python3 cliptest.py c8-rocky8-tmux27 $S 'ssh -t $S docker exec -it -e TERM=xterm-256color cliprocky8 tmux new -s nv vim /root/t/yank.txt'" 2>&1 | tee "$TMPDIR/cliptest.txt"
grep -E '^(RESULT|vim sees)' "$TMPDIR/cliptest.txt"
```

Expected RESULT lines (anything else is a bug to fix before shipping):

| Chain | tmux-buffer | paste-own | paste-other-pane | client OSC 52 | local-tmux-buffer |
|---|---|---|---|---|---|
| c1 ssh→tmux | OK | OK | OK | OK | – |
| c2 mosh→tmux | OK | OK | OK | OK | – |
| c3 tmux→ssh→tmux | OK | OK | OK | OK | OK |
| c4 tmux→mosh→tmux | OK | OK | OK | OK | OK |
| c5 ssh, no tmux | – | – | – | OK | – |
| c6 `$TMUX` lost | OK (my-tmux `set-clipboard on` stores app OSC 52) | OK | FAILED (expected: osc52 mode doesn't read the tmux buffer) | OK | – |
| c7 stock tmux | OK | OK | OK | OK | – |
| c8 Rocky 8, tmux 2.7 | OK | OK | OK | OK | – |

`vim sees:` must show `mode=tmux` for c1–c4, c7, c8 and `mode=osc52` for c6. Paste the table of actual results into the PR body.

- [ ] **Step 11: Clean up** `ssh claude@$SRV docker rm -f cliprocky8`.

- [ ] **Step 12: Ship** (branch `task-06-clipboard`, message `Clipboard through tmux, ssh and mosh (OSC 52, tmux buffer)`).

---

### Task 7: Ansible filetype and role-aware gf

**Files:**
- Create: `ftdetect/ansible.vim`, `after/ftplugin/yaml.vim`, `autoload/myvim/ansible.vim`
- Create: `tests/expect/50-ansible.vim`

**Interfaces:**
- Consumes: `myvim#find#files(hidden, query)` (Task 9) for the "role not found" fallback; called through `exists('*myvim#find#files')`-safe autoload, and the fallback is skipped (message only) until Task 9 exists.
- Produces: `myvim#ansible#gf()`.

- [ ] **Step 1: Branch** `task-07-ansible`.

- [ ] **Step 2: Write the failing `tests/expect/50-ansible.vim`**

```vim
" core/ansible.lua: yaml.ansible filetype and gf to role tasks
let s:a = "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/ansible/"
call Scenario('eval', 'role tasks are yaml.ansible', [], s:a . "roles/web/tasks/main.yml')", '', '&filetype', 'yaml.ansible')
call Scenario('eval', 'playbooks are yaml.ansible', [], s:a . "playbooks/site.yml')", '', '&filetype', 'yaml.ansible')
call Scenario('eval', 'other yaml stays yaml', [], "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/sample.yaml')", '', '&filetype', 'yaml')
call Scenario('eval', 'gf on a role opens tasks/main.yml', [], s:a . "playbooks/site.yml')", '3G$gf', "expand('%:p:h:h:t') . '/' . expand('%:t')", 'web/main.yml')
call Scenario('eval', 'gf with tasks_from opens that file', [], s:a . "playbooks/site.yml')", '7G$gf', "expand('%:p:h:h:t') . '/' . expand('%:t')", 'web/extra.yml')
call Scenario('eval', 'gf on a path relative to the file', ['../roles/web/tasks/extra.yml'], s:a . "playbooks/site.yml') | call setline(9, '# ../roles/web/tasks/extra.yml')", '9G$gf', "expand('%:t')", 'extra.yml')
unlet s:a
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh bare rocky8`).

- [ ] **Step 4: Write `ftdetect/ansible.vim`**

```vim
" yaml.ansible for playbooks and role tasks (core/ansible.lua). Runs after
" vim's own yaml detection, so `set filetype` (not setfiletype) wins.
autocmd BufRead,BufNewFile */playbooks/*.yml,*/playbooks/*.yaml,*/roles/*/tasks/*.yml,*/roles/*/tasks/*.yaml,*/ansible/*.yml,*/ansible/*.yaml set filetype=yaml.ansible
```

- [ ] **Step 5: Write `after/ftplugin/yaml.vim`** (vim loads it for `yaml` and for the `yaml` part of `yaml.ansible`; in `after/` so it runs after vim's own yaml ftplugin, which sets `b:undo_ftplugin`)

```vim
" gf that knows Ansible roles (core/ansible.lua)
if !exists('g:myvim_tier') | finish | endif
nnoremap <buffer> <silent> gf :call myvim#ansible#gf()<CR>
let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') . ' | silent! nunmap <buffer> gf'
```

- [ ] **Step 6: Write `autoload/myvim/ansible.vim`**

```vim
" gf on a role name (roles:, role:, include_role, tasks_from) opens the
" role's tasks file; anywhere else it opens the file under the cursor.

" roles/<role>/tasks/<file> in the file's directory or any directory above
" (a playbook next to roles/ or in playbooks/, a role calling a role)
function! s:find_role_tasks(role, file) abort
  let dir = expand('%:p:h')
  while 1
    let cands = [dir . '/roles/' . a:role . '/tasks/' . a:file]
    if fnamemodify(dir, ':t') ==# 'roles'
      call add(cands, dir . '/' . a:role . '/tasks/' . a:file)
    endif
    for p in cands
      if filereadable(p)
        return p
      endif
    endfor
    let parent = fnamemodify(dir, ':h')
    if parent ==# dir
      return ''
    endif
    let dir = parent
  endwhile
endfunction

function! myvim#ansible#gf() abort
  let word = expand('<cword>')
  let cfile = expand('<cfile>')
  let row = line('.')
  let w = '\V' . escape(word, '\')
  let role_style = 0
  let include_role = 0
  let tasks_from = ''
  for l in getline(max([row - 2, 1]), row + 2)
    if l =~# 'role\s*:\s*' . w || l =~# 'roles\s*:' || l =~# '^\s*-\s*' . w
      let role_style = 1
    endif
    if l =~# 'include_role'
      let include_role = 1
    endif
    let m = matchlist(l, 'tasks_from\s*:\s*\(.\+\)')
    if !empty(m)
      let tasks_from = substitute(m[1], '^\s*\|\s*$', '', 'g')
      if tasks_from !~# '\.ya\?ml$'
        let tasks_from .= '.yml'
      endif
    endif
  endfor

  if role_style || include_role
    let target = empty(tasks_from) ? 'main.yml' : tasks_from
    let path = s:find_role_tasks(word, target)
    if !empty(path)
      execute 'edit' fnameescape(path)
      return
    endif
    " one line: a longer message stops at "Press ENTER" before the finder opens
    echohl Comment | echo printf('Role %s (tasks/%s) not found: searching files', word, target) | echohl None
    if exists('g:myvim_plugins') && (index(g:myvim_plugins, 'fzf.vim') >= 0 || index(g:myvim_plugins, 'ctrlp.vim') >= 0)
      call myvim#find#files(0, word)
    endif
    return
  endif

  let abs = expand('%:p:h') . '/' . cfile
  if filereadable(abs)
    execute 'edit' fnameescape(abs)
    return
  endif
  try
    normal! gf
  catch
    echohl Comment | echo 'File not found: ' . cfile | echohl None
  endtry
endfunction
```

- [ ] **Step 7: Run, expect pass** (`run-matrix.sh`). centos7 has no packages but does load `ftdetect`/`ftplugin`/`autoload` from `~/.vim`, so these scenarios run there too.

- [ ] **Step 8: Ship** (branch `task-07-ansible`, message `Port Ansible filetype detection and role-aware gf`).

---

### Task 8: Vendoring tooling and the plugins

**Files:**
- Create: `plugins.list`, `update-plugins.sh`
- Create: `pack/vendor/opt/*` (generated)
- Create: `tests/expect/60-plugins.vim` (load checks only; config is Task 9)

**Interfaces:**
- Produces: `pack/vendor/opt/<name>` for every name in `vimrc`'s `s:want` table; `plugins.list` format `name url commit [pathspec...]`.

- [ ] **Step 1: Branch** `task-08-vendor`.

- [ ] **Step 2: Write the failing `tests/expect/60-plugins.vim`**

```vim
" Vendored plugins load (by tier); their settings and keys are checked in 61-plugin-config.vim
for s:p in ['vim-nightfly-colors', 'vim-fugitive', 'vim-surround', 'vim-commentary', 'vim-repeat',
      \ 'ReplaceWithRegister', 'vim-tmux-navigator', 'undotree', 'vim-maximizer', 'nerdtree',
      \ 'vim-gitgutter', 'lightline.vim', 'auto-pairs', 'indentLine', 'ctrlp.vim', 'vista.vim']
  call Expect('1', "index(g:myvim_plugins, '" . s:p . "') >= 0", 1)
endfor
for s:p in ['vim-lsp', 'asyncomplete.vim', 'asyncomplete-lsp.vim', 'asyncomplete-buffer.vim', 'asyncomplete-file.vim', 'ale']
  call Expect('2', "index(g:myvim_plugins, '" . s:p . "') >= 0", 1)
endfor
call Expect('fzf', "index(g:myvim_plugins, 'fzf.vim') >= 0", 1)
call Expect('nofzf', "index(g:myvim_plugins, 'fzf.vim')", -1)
call Expect('1', "exists(':Git')", 2)
call Expect('1', "exists(':NERDTree')", 2)
call Expect('1', "exists(':CtrlP')", 2)
call Expect('1', "exists(':UndotreeToggle')", 2)
call Expect('1', "exists(':MaximizerToggle')", 2)
call Expect('1', "exists(':Vista')", 2)
call Expect('1', "exists(':TmuxNavigateLeft')", 2)
call Expect('fzf', "exists(':Files')", 2)
call Expect('2', "exists(':LspDefinition')", 2)
call Expect('2', "exists(':ALELint')", 2)
call Expect('1', "!empty(globpath(&runtimepath, 'doc/tags'))", 1)
unlet s:p
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh tools bare rocky8`).

- [ ] **Step 4: Write `plugins.list`** (commits are the remote HEADs on 2026-10-10; `update-plugins.sh` expands them to full SHAs)

```text
# Vendored into pack/vendor/opt/<name> by update-plugins.sh.
# name                     url                                                      commit        [pathspec...]
vim-nightfly-colors        https://github.com/bluz71/vim-nightfly-colors            2c31d07ce05e
vim-fugitive               https://github.com/tpope/vim-fugitive                    3b753cf8c6a4
vim-surround               https://github.com/tpope/vim-surround                    3d188ed21134
vim-commentary             https://github.com/tpope/vim-commentary                  64a654ef4a20
vim-repeat                 https://github.com/tpope/vim-repeat                      65846025c154
ReplaceWithRegister        https://github.com/vim-scripts/ReplaceWithRegister       832efc23111d
vim-tmux-navigator         https://github.com/christoomey/vim-tmux-navigator        e41c431a0c7b
undotree                   https://github.com/mbbill/undotree                       6fa6b57cda84
vim-maximizer              https://github.com/szw/vim-maximizer                     2e54952fe91e
nerdtree                   https://github.com/preservim/nerdtree                    690d061b5915
vim-gitgutter              https://github.com/airblade/vim-gitgutter                90b75207bd9b
lightline.vim              https://github.com/itchyny/lightline.vim                 255f61db1a4c  . :(exclude)test
auto-pairs                 https://github.com/jiangmiao/auto-pairs                  39f06b873a84
indentLine                 https://github.com/Yggdroot/indentLine                   b96a75985736
ctrlp.vim                  https://github.com/ctrlpvim/ctrlp.vim                    0065942ef13c
vista.vim                  https://github.com/liuchengxu/vista.vim                  1e90efad6e32
fzf                        https://github.com/junegunn/fzf                          33a3456921a1  plugin doc LICENSE
fzf.vim                    https://github.com/junegunn/fzf.vim                      023de3c0e158
vim-lsp                    https://github.com/prabirshrestha/vim-lsp                81481196aa69  . :(exclude)test
asyncomplete.vim           https://github.com/prabirshrestha/asyncomplete.vim       17b654a87a83
asyncomplete-lsp.vim       https://github.com/prabirshrestha/asyncomplete-lsp.vim   7cf65e7661a6
asyncomplete-buffer.vim    https://github.com/prabirshrestha/asyncomplete-buffer.vim a7afcf4f1f0e
asyncomplete-file.vim      https://github.com/prabirshrestha/asyncomplete-file.vim  770772daf1ff
ale                        https://github.com/dense-analysis/ale                    e1789bc54483  . :(exclude)test :(exclude)supported-tools.md
```

- [ ] **Step 5: Write `update-plugins.sh`**

```bash
#!/bin/bash
# Vendors the plugins in plugins.list into pack/vendor/opt/<name> (no .git),
# rewrites plugins.list with full commit SHAs and rebuilds the help tags.
# Dev machine only (needs git and network); commit the result.
#   ./update-plugins.sh             vendor every plugin at its pinned commit
#   ./update-plugins.sh --bump      move every pin to the remote HEAD first
#   ./update-plugins.sh --bump NAME only that plugin moves
set -euo pipefail
cd "$(dirname "$0")"
bump=0; only=
[ "${1:-}" = --bump ] && { bump=1; only=${2:-}; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
: > "$tmp/list"
while IFS= read -r line; do
  case $line in ''|'#'*) echo "$line" >> "$tmp/list"; continue ;; esac
  read -r name url ref paths <<< "$line"
  if [ $bump = 1 ] && { [ -z "$only" ] || [ "$name" = "$only" ]; }; then
    ref=$(git ls-remote "$url" HEAD | cut -f1)
  fi
  git clone -q --filter=blob:none "$url" "$tmp/$name"
  git -C "$tmp/$name" checkout -q "$ref"
  ref=$(git -C "$tmp/$name" rev-parse HEAD)
  dest=pack/vendor/opt/$name
  rm -rf "$dest"; mkdir -p "$dest"
  # shellcheck disable=SC2086 # paths is a list of pathspecs
  git -C "$tmp/$name" archive HEAD -- ${paths:-.} | tar -x -C "$dest"
  printf '%-26s %-57s %s%s\n' "$name" "$url" "$ref" "${paths:+  $paths}" >> "$tmp/list"
  echo "vendored $name ${ref:0:12}"
done < plugins.list
mv "$tmp/list" plugins.list
rm -f pack/vendor/opt/*/doc/tags
vim -Nu NONE -es -c 'for d in glob("pack/vendor/opt/*/doc", 0, 1) | execute "helptags" fnameescape(d) | endfor' -c 'qa!'
du -sh pack/vendor
```

- [ ] **Step 6: Vendor**

Run: `chmod +x update-plugins.sh && ./update-plugins.sh`
Expected: 24 `vendored ...` lines, `plugins.list` now with 40-char SHAs, a size under ~15 MB from `du`. If one plugin's archive is surprisingly large (> 3 MB), add `:(exclude)` pathspecs for its test/media dirs to its line and rerun.

- [ ] **Step 7: Run, expect pass** (`run-matrix.sh`). Then handle old vims: for each FAIL / `MSG E...` on `rocky8` or `ubuntu1604` caused by a plugin at load time, give that plugin a condition in `vimrc`'s `s:want` (for example `['vim-gitgutter', v:version > 704 || has('patch-7.4.1826')]`, using the version from the plugin's README or error) and make the matching Expect in `60-plugins.vim` use the same condition. Rerun until all cases PASS. List each condition you added in the PR body.

- [ ] **Step 8: Ship** (branch `task-08-vendor`, message `Vendor the plugins under pack/vendor/opt`). The PR is large: put `du -sh pack/vendor` and the plugins.list diff summary in the body.

---

### Task 9: Plugin settings and keymaps (finders, tree, git, look)

**Files:**
- Create: `plugin/plugins.vim`, `autoload/myvim/find.vim`, `autoload/myvim/tree.vim`, `autoload/myvim/term.vim`, `autoload/myvim/complete.vim`, `autoload/myvim/colors.vim`, `autoload/lightline/colorscheme/myvim.vim`
- Create: `tests/expect/61-plugin-config.vim`

**Interfaces:**
- Consumes: `g:myvim_fzf`, `g:myvim_plugins`.
- Produces: `myvim#find#files(hidden, [query])`, `myvim#find#grep(word)`, `myvim#find#in_file()`, `myvim#find#git_branches()`, `myvim#tree#find_toggle()`, `myvim#tree#collapse()`, `myvim#tree#refresh()`, `myvim#tree#expand_all()`, `myvim#term#toggle(where)`, `myvim#complete#cr()`, `myvim#colors#overrides()`.

- [ ] **Step 1: Branch** `task-09-plugin-config`.

- [ ] **Step 2: Write the failing `tests/expect/61-plugin-config.vim`**

```vim
" plugin keymaps and settings (telescope, nvim-tree, gitsigns, lualine, ...)
for s:m in ['<Space>ff', '<Space>fF', '<Space>fs', '<Space>fc', '<Space>fe', '<Space>fb', '<Space>fh',
      \ '<Space>fht', '<Space>fg', '<Space>fgf', '<Space>fgs', '<Space>fgb', '<Space>fgc', '<Space>fu',
      \ '<Space>fgdw', '<Space>fgdfc', '<Space>fgdfa', '<Space>ee', '<Space>ef', '<Space>ec',
      \ '<Space>er', '<Space>ea', '<Space>ut', '<Space>up', '<Space>sm', '<Space>mo', '<Space>mf',
      \ '<C-h>', '<C-j>', '<C-k>', '<C-l>', 'gcc', 'ys', 'grr']
  call ExpectMap('1', 'n', s:m)
endfor
call ExpectMap('term', 'n', '<Space>ttt')
call ExpectMap('term', 'n', '<Space>ttv')
call ExpectMap('term', 't', '<C-h>')
call ExpectMap('1', 'i', '<CR>')
unlet s:m
call Expect('1', "get(g:, 'colors_name', '')", 'nightfly')
call Expect('1', '&showtabline', 2)
call Expect('1', '&showmode', 0)
call Expect('1', "get(get(g:, 'lightline', {}), 'colorscheme', '')", 'myvim')
call Expect('1', "&termguicolors ? synIDattr(hlID('CursorLine'), 'bg#') : '#202d69'", '#202d69')
call Expect('1', "get(g:, 'gitgutter_map_keys', 1)", 0)
call Expect('1', "get(g:, 'AutoPairsShortcutToggle', '<M-p>')", '')
call Expect('fzf', "$FZF_DEFAULT_OPTS =~# 'ctrl-j:down'", 1)
call Scenario('1', 'indentLine leaves json quotes visible', [], "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/sample.json')", '', '&l:conceallevel', 0)
call Scenario('1', '<leader>ee opens NERDTree', [], 'cd ' . fnameescape(g:myvim_root), "\<Space>ee", "len(filter(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), \"&filetype\") ==# \"nerdtree\"'))", 1)
call Scenario('1', '<leader>ea then <leader>ec without errors', [], 'cd ' . fnameescape(g:myvim_root . '/tests'), "\<Space>ee\<C-w>p\<Space>ea\<Space>ec", 'v:errmsg', '')
call Scenario('1', 'gcc comments a line', ['x = 1'], 'setfiletype python', 'gcc', 'getline(1)', '# x = 1')
call Scenario('1', 'griw replaces a word with the register', ['old word'], 'let @" = "new"', 'griw', 'getline(1)', 'new word')
call Scenario('1', 'ysiw" surrounds', ['word'], '', 'ysiw"', 'getline(1)', '"word"')
call Scenario('1', '<CR> after ( opens a pair on new lines', [''], '', "if(\<CR>\<Esc>", 'line("$")', 3)
silent! NERDTreeClose
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh tools bare rocky8`).

- [ ] **Step 4: Write `plugin/plugins.vim`**

```vim
" Settings and keymaps of the vendored plugins (tier 1). Same keys as
" my-nvim's lazy_plugins/*.lua; LSP keys are in plugin/lsp.vim.
if !exists('g:myvim_tier') || g:myvim_tier < 1 | finish | endif

" look: nightfly + lualine's colours in lightline (bufferline ran in tabs mode)
let g:nightflyCursorColor = 1
let g:nightflyWinSeparator = 2
if &encoding ==# 'utf-8'
  set fillchars+=vert:┃
endif
augroup myvim_colors
  autocmd!
  autocmd ColorScheme * call myvim#colors#overrides()
augroup END
silent! colorscheme nightfly
let g:lightline = {
  \ 'colorscheme': 'myvim',
  \ 'active': {
  \   'left': [['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified']],
  \   'right': [['lineinfo'], ['percent'], ['fileencoding', 'fileformat', 'filetype']],
  \ },
  \ 'component_function': {'gitbranch': 'FugitiveHead'},
  \ 'tabline': {'left': [['tabs']], 'right': []},
  \ }
set noshowmode
set showtabline=2

" finders (telescope): fzf.vim with a recent fzf, else ctrlp and :grep
let g:ctrlp_use_caching = 0
let g:ctrlp_working_path_mode = ''
if g:myvim_fzf
  if empty($FZF_DEFAULT_COMMAND) && executable('rg')
    let $FZF_DEFAULT_COMMAND = 'rg --files'
  endif
  let $FZF_DEFAULT_OPTS = $FZF_DEFAULT_OPTS . ' --bind=ctrl-j:down,ctrl-k:up'
endif
nnoremap <silent> <leader>ff :call myvim#find#files(0)<CR>
nnoremap <silent> <leader>fF :call myvim#find#files(1)<CR>
nnoremap <silent> <leader>fs :call myvim#find#grep(0)<CR>
nnoremap <silent> <leader>fc :call myvim#find#grep(1)<CR>
nnoremap <silent> <leader>fe :call myvim#find#in_file()<CR>
nnoremap <silent> <leader>fgb :call myvim#find#git_branches()<CR>
if g:myvim_fzf
  nnoremap <silent> <leader>fb :Buffers<CR>
  nnoremap <silent> <leader>fh :Helptags<CR>
  nnoremap <silent> <leader>fht :Helptags<CR>
  nnoremap <silent> <leader>fg :GFiles<CR>
  nnoremap <silent> <leader>fgf :GFiles<CR>
  nnoremap <silent> <leader>fgs :GFiles?<CR>
  nnoremap <silent> <leader>fgc :Commits<CR>
else
  nnoremap <silent> <leader>fb :CtrlPBuffer<CR>
  nnoremap <leader>fh :help<Space>
  nnoremap <leader>fht :help<Space>
  nnoremap <silent> <leader>fg :call myvim#find#files(0)<CR>
  nnoremap <silent> <leader>fgf :call myvim#find#files(0)<CR>
  nnoremap <silent> <leader>fgs :Git<CR>
  nnoremap <silent> <leader>fgc :Git log --oneline --decorate -50<CR>
endif
nnoremap <silent> <leader>fu :UndotreeToggle<CR>

" git (neogit / diffview -> fugitive), gitsigns -> gitgutter
nnoremap <silent> <leader>fgdw :Git diff<CR>
nnoremap <silent> <leader>fgdfc :0Gclog<CR>
nnoremap <silent> <leader>fgdfa :Gclog<CR>
let g:gitgutter_map_keys = 0

" file tree (nvim-tree -> NERDTree)
let g:NERDTreeWinSize = 30
let g:NERDTreeShowHidden = 1
let g:NERDTreeIgnore = ['^\.git$']
nnoremap <silent> <leader>ee :NERDTreeToggle<CR>
nnoremap <silent> <leader>ef :call myvim#tree#find_toggle()<CR>
nnoremap <silent> <leader>ec :call myvim#tree#collapse()<CR>
nnoremap <silent> <leader>er :call myvim#tree#refresh()<CR>
nnoremap <silent> <leader>ea :call myvim#tree#expand_all()<CR>

" undotree, maximizer
let g:undotree_WindowLayout = 3
nnoremap <silent> <leader>ut :UndotreeToggle<CR>
nnoremap <silent> <leader>up :UndotreePersistUndo<CR>
nnoremap <silent> <leader>sm :MaximizerToggle<CR>

" outline (outline.nvim -> vista): vista follows the cursor by itself
let g:vista_default_executive = g:myvim_tier >= 2 ? 'vim_lsp' : 'ctags'
let g:vista#renderer#enable_icon = 0
nnoremap <silent> <leader>mo :Vista!!<CR>
nnoremap <silent> <leader>mf :Vista focus<CR>

" auto-pairs: no Alt shortcuts (harpoon has <M-p>/<M-n>/<M-e>), <CR> is ours
let g:AutoPairsShortcutToggle = ''
let g:AutoPairsShortcutFastWrap = ''
let g:AutoPairsShortcutJump = ''
let g:AutoPairsShortcutBackInsert = ''
let g:AutoPairsMapCR = 0
set completeopt=menu,menuone,noselect
inoremap <silent> <expr> <CR> myvim#complete#cr()

" indent guides (indent-blankline): one colour; conceal would hide quotes
let g:indentLine_char = '│'
let g:indentLine_color_gui = '#61AFEF'
let g:indentLine_color_term = 75
let g:indentLine_fileTypeExclude = ['json', 'jsonc', 'markdown', 'help', 'nerdtree', 'undotree', 'vista']
let g:indentLine_bufTypeExclude = ['help', 'terminal', 'nofile']
let g:vim_json_conceal = 0
let g:markdown_syntax_conceal = 0

" terminal (toggleterm)
if has('terminal')
  nnoremap <silent> <leader>ttt :call myvim#term#toggle('tab')<CR>
  nnoremap <silent> <leader>ttv :call myvim#term#toggle('split')<CR>
  tnoremap <silent> <C-h> <C-w>h
  tnoremap <silent> <C-j> <C-w>j
  tnoremap <silent> <C-k> <C-w>k
  tnoremap <silent> <C-l> <C-w>l
endif
```

- [ ] **Step 5: Write `autoload/myvim/colors.vim`**

```vim
" Highlight overrides from my-nvim's colorscheme.lua and nvim-tree.lua
function! myvim#colors#overrides() abort
  highlight CursorLine gui=NONE cterm=NONE guibg=#202d69 ctermbg=17
  highlight DiffAdd guifg=#81b88b guibg=NONE ctermfg=108 ctermbg=NONE
  highlight DiffChange guifg=#e2c08d guibg=NONE ctermfg=180 ctermbg=NONE
  highlight DiffText guifg=#c586c0 guibg=NONE gui=bold ctermfg=176 ctermbg=NONE cterm=bold
  highlight DiffDelete guifg=#c74e39 guibg=NONE ctermfg=167 ctermbg=NONE
  highlight NERDTreeOpenable guifg=#3FC5FF ctermfg=81
  highlight NERDTreeClosable guifg=#3FC5FF ctermfg=81
endfunction
```

- [ ] **Step 6: Write `autoload/lightline/colorscheme/myvim.vim`**

```vim
" lualine.lua's theme for lightline: [gui, cterm] per colour
let s:blue = ['#65D1FF', 81]
let s:green = ['#3EFFDC', 86]
let s:violet = ['#FF61EF', 207]
let s:yellow = ['#FFDA7B', 222]
let s:red = ['#FF4A4A', 203]
let s:black = ['#000000', 16]
let s:fg = ['#c3ccdc', 252]
let s:bg = ['#112638', 235]
let s:inactive_bg = ['#2c3043', 236]

let s:p = {'normal': {}, 'inactive': {}, 'insert': {}, 'replace': {}, 'visual': {}, 'command': {}, 'tabline': {}}
let s:p.normal.left = [[s:bg, s:blue, 'bold'], [s:fg, s:bg]]
let s:p.normal.middle = [[s:fg, s:bg]]
let s:p.normal.right = [[s:bg, s:blue, 'bold'], [s:fg, s:bg]]
let s:p.normal.error = [[s:bg, s:red]]
let s:p.normal.warning = [[s:bg, s:yellow]]
let s:p.insert.left = [[s:bg, s:green, 'bold'], [s:fg, s:bg]]
let s:p.insert.right = [[s:bg, s:green, 'bold'], [s:fg, s:bg]]
let s:p.visual.left = [[s:bg, s:violet, 'bold'], [s:fg, s:bg]]
let s:p.visual.right = [[s:bg, s:violet, 'bold'], [s:fg, s:bg]]
let s:p.command.left = [[s:black, s:yellow, 'bold'], [s:fg, s:bg]]
let s:p.command.right = [[s:black, s:yellow, 'bold'], [s:fg, s:bg]]
let s:p.replace.left = [[s:bg, s:red, 'bold'], [s:fg, s:bg]]
let s:p.replace.right = [[s:bg, s:red, 'bold'], [s:fg, s:bg]]
let s:p.inactive.left = [[s:fg, s:inactive_bg, 'bold'], [s:fg, s:inactive_bg]]
let s:p.inactive.middle = [[s:fg, s:inactive_bg]]
let s:p.inactive.right = [[s:fg, s:inactive_bg], [s:fg, s:inactive_bg]]
let s:p.tabline.left = [[s:fg, s:inactive_bg]]
let s:p.tabline.tabsel = [[s:bg, s:blue, 'bold']]
let s:p.tabline.middle = [[s:fg, s:bg]]
let s:p.tabline.right = [[s:fg, s:bg]]

let g:lightline#colorscheme#myvim#palette = lightline#colorscheme#fill(s:p)
```

- [ ] **Step 7: Write `autoload/myvim/find.vim`**

```vim
" <leader>f* finders: fzf.vim when g:myvim_fzf, else ctrlp and :grep

" files under DIR ('.' for fzf, '%s' for ctrlp's user_command)
function! s:list_cmd(hidden, dir) abort
  if executable('rg')
    return 'rg --files' . (a:hidden ? ' --hidden --no-ignore --follow ' : ' ') . a:dir
  endif
  return a:hidden ? 'find -L ' . a:dir . ' -type f' : 'find ' . a:dir . " -type f -not -path '*/.git/*'"
endfunction

" files(hidden [, query]): a query opens the only match straight away
function! myvim#find#files(hidden, ...) abort
  let query = a:0 ? a:1 : ''
  if g:myvim_fzf
    let spec = {'source': s:list_cmd(a:hidden, '.')}
    if !empty(query)
      let spec.options = ['--query', query, '--select-1']
    endif
    call fzf#vim#files('', spec)
  else
    let g:ctrlp_user_command = s:list_cmd(a:hidden, '%s')
    let g:ctrlp_default_input = query
    CtrlP
    let g:ctrlp_default_input = ''
  endif
endfunction

" grep(word): live grep (0) or the word under the cursor (1)
function! myvim#find#grep(word) abort
  if g:myvim_fzf && executable('rg')
    if a:word
      call fzf#vim#grep('rg --column --line-number --no-heading --color=always --smart-case -- ' . shellescape(expand('<cword>')), {})
    else
      RG
    endif
    return
  endif
  let pat = a:word ? expand('<cword>') : input('Grep > ')
  if empty(pat)
    return
  endif
  execute 'silent grep!' shellescape(pat, 1)
  redraw!
  botright cwindow
endfunction

" search in the current file
function! myvim#find#in_file() abort
  if g:myvim_fzf
    BLines
    return
  endif
  let pat = input('Search in file > ')
  if empty(pat)
    return
  endif
  execute 'silent! lvimgrep /' . escape(pat, '/') . '/j %'
  lwindow
endfunction

function! myvim#find#git_branches() abort
  if g:myvim_fzf
    call fzf#run(fzf#wrap({'source': "git branch --all --format='%(refname:short)'", 'sink': function('s:switch')}))
  else
    Git branch --all
  endif
endfunction

function! s:switch(branch) abort
  execute 'Git switch' substitute(a:branch, '^origin/', '', '')
endfunction
```

- [ ] **Step 8: Write `autoload/myvim/tree.vim`**

```vim
" NERDTree helpers for <leader>ef ec er ea (nvim-tree.lua)
function! s:is_open() abort
  return exists('g:NERDTree') && g:NERDTree.IsOpen()
endfunction

function! myvim#tree#find_toggle() abort
  if s:is_open()
    NERDTreeClose
  elseif empty(expand('%'))
    NERDTree
  else
    NERDTreeFind
  endif
endfunction

" run FN inside the tree window, then come back
function! s:in_tree(fn) abort
  if s:is_open()
    NERDTreeFocus
  else
    NERDTree
  endif
  call call(a:fn, [])
  wincmd p
endfunction

function! s:collapse() abort
  call b:NERDTree.root.closeChildren()
  call b:NERDTree.render()
endfunction

function! s:refresh() abort
  call b:NERDTree.root.refresh()
  call b:NERDTree.render()
endfunction

function! s:expand() abort
  call b:NERDTree.root.openRecursively()
  call b:NERDTree.render()
endfunction

function! myvim#tree#collapse() abort
  call s:in_tree(function('s:collapse'))
endfunction

function! myvim#tree#refresh() abort
  call s:in_tree(function('s:refresh'))
endfunction

function! myvim#tree#expand_all() abort
  call s:in_tree(function('s:expand'))
endfunction
```

- [ ] **Step 9: Write `autoload/myvim/term.vim`**

```vim
" <leader>ttt / <leader>ttv (toggleterm): show the running terminal in a tab
" or a bottom split, hide the split again, or start one
function! myvim#term#toggle(where) abort
  for w in range(1, winnr('$'))
    if getbufvar(winbufnr(w), '&buftype') ==# 'terminal' && a:where ==# 'split'
      execute w . 'close'
      return
    endif
  endfor
  let running = filter(range(1, bufnr('$')), 'bufexists(v:val) && getbufvar(v:val, "&buftype") ==# "terminal" && term_getstatus(v:val) =~# "running"')
  if a:where ==# 'tab'
    if empty(running) | tab terminal ++close | else | execute 'tab sbuffer' running[0] | endif
  else
    if empty(running) | botright terminal ++close | else | execute 'botright sbuffer' running[0] | endif
  endif
endfunction
```

- [ ] **Step 10: Write `autoload/myvim/complete.vim`**

```vim
" <CR> in insert mode (nvim-cmp): accept a selected completion, otherwise a
" newline (closing an unselected popup), with auto-pairs' return handling
function! myvim#complete#cr() abort
  let pairs = exists('*AutoPairsReturn') ? "\<C-r>=AutoPairsReturn()\<CR>" : ''
  if pumvisible()
    if !exists('*complete_info') || complete_info(['selected']).selected >= 0
      return "\<C-y>"
    endif
    return "\<C-e>\<CR>" . pairs
  endif
  return "\<CR>" . pairs
endfunction
```

- [ ] **Step 11: Run, expect pass** (`run-matrix.sh`). `tools` exercises fzf; `bare` has apt's fzf 0.44 (< 0.63), so it exercises ctrlp. Check by hand once in the VM (`ssh -t claude@$SRV tmux new vim ~/my-vim/README.md`, press `<Space>ff`, `<Space>fs`, `<Space>ee`): the pickers open and `<C-j>/<C-k>` move.

- [ ] **Step 12: Ship** (branch `task-09-plugin-config`, message `Plugin settings and keymaps: finders, tree, git, look`).

---

### Task 10: Harpoon

**Files:**
- Create: `plugin/harpoon.vim`, `autoload/myvim/harpoon.vim`, `tests/expect/70-harpoon.vim`

**Interfaces:**
- Consumes: `g:myvim_state`.
- Produces: `myvim#harpoon#list()`, `myvim#harpoon#add()`, `myvim#harpoon#select(n)`, `myvim#harpoon#cycle(step)`, `myvim#harpoon#menu()`.

- [ ] **Step 1: Branch** `task-10-harpoon`.

- [ ] **Step 2: Write the failing `tests/expect/70-harpoon.vim`**

```vim
" harpoon.lua: per-cwd list of files
for s:m in ['<Space>aa', '<M-e>', '<M-h>', '<M-j>', '<M-k>', '<M-l>', '<M-p>', '<M-n>']
  call ExpectMap('eval', 'n', s:m)
endfor
unlet s:m
let s:setup = "call mkdir('/tmp/myvim-hp', 'p') | cd /tmp/myvim-hp | call writefile(['a'], 'a.txt') | call writefile(['b'], 'b.txt')"
      \ . " | call delete(g:myvim_state . '/harpoon/' . substitute(getcwd(), '/', '%', 'g'))"
      \ . " | edit a.txt | call myvim#harpoon#add() | edit b.txt | call myvim#harpoon#add()"
call Scenario('eval', 'add keeps the order', [], s:setup, '', 'myvim#harpoon#list()', ['a.txt', 'b.txt'])
call Scenario('eval', '<M-h> opens entry 1', [], s:setup, "\<M-h>", "expand('%:t')", 'a.txt')
call Scenario('eval', '<M-j> opens entry 2', [], s:setup, "\<M-h>\<M-j>", "expand('%:t')", 'b.txt')
call Scenario('eval', '<M-p> from entry 2 goes to 1', [], s:setup, "\<M-p>", "expand('%:t')", 'a.txt')
call Scenario('eval', '<M-k> with no entry 3 stays and is quiet', [], s:setup, "\<M-k>", "[expand('%:t'), v:errmsg]", ['b.txt', ''])
call Scenario('eval', '<M-e> menu lists the files', [], s:setup, "\<M-e>", "[&buftype, getline(1, '$')]", ['acwrite', ['a.txt', 'b.txt']])
call Scenario('eval', 'deleting a line in the menu and :w saves it', [], s:setup, "\<M-e>dd:w\<CR>", 'myvim#harpoon#list()', ['b.txt'])
unlet s:setup
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh bare rocky8`).

- [ ] **Step 4: Write `autoload/myvim/harpoon.vim`**

```vim
" A small harpoon (harpoon.lua): a list of files per working directory,
" kept in <state>/harpoon/<cwd with / as %>.

function! s:path() abort
  return g:myvim_state . '/harpoon/' . substitute(getcwd(), '/', '%', 'g')
endfunction

function! myvim#harpoon#list() abort
  if empty(g:myvim_state) || !filereadable(s:path())
    return []
  endif
  return filter(readfile(s:path()), 'v:val !~# "^\\s*$"')
endfunction

function! s:save(list) abort
  if empty(g:myvim_state)
    echo 'harpoon: no state dir'
    return
  endif
  call writefile(a:list, s:path())
endfunction

function! myvim#harpoon#add() abort
  if empty(expand('%'))
    echo 'harpoon: buffer has no file'
    return
  endif
  let rel = fnamemodify(expand('%:p'), ':.')
  let list = myvim#harpoon#list()
  if index(list, rel) < 0
    call add(list, rel)
    call s:save(list)
  endif
  echo 'harpoon: ' . rel . ' (' . (index(list, rel) + 1) . ')'
endfunction

function! myvim#harpoon#select(n) abort
  let list = myvim#harpoon#list()
  if a:n < 1 || a:n > len(list)
    echo 'harpoon: no file ' . a:n
    return
  endif
  execute 'edit' fnameescape(list[a:n - 1])
endfunction

" <M-p>/<M-n>: previous/next entry, no wrap (harpoon's default)
function! myvim#harpoon#cycle(step) abort
  let list = myvim#harpoon#list()
  if empty(list)
    return
  endif
  let i = index(list, fnamemodify(expand('%:p'), ':.'))
  let n = i < 0 ? 1 : min([max([i + 1 + a:step, 1]), len(list)])
  call myvim#harpoon#select(n)
endfunction

" <M-e>: the list in a buffer; edit lines, :w or q saves, <CR> opens
function! myvim#harpoon#menu() abort
  let list = myvim#harpoon#list()
  execute 'botright' min([max([len(list), 1]), 10]) . 'new'
  setlocal buftype=acwrite bufhidden=wipe noswapfile nobuflisted
  execute 'file' fnameescape('harpoon://' . getcwd())
  call setline(1, list)
  setlocal nomodified
  augroup myvim_harpoon_menu
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:menu_save()
  augroup END
  nnoremap <buffer> <silent> q :call <SID>menu_close()<CR>
  nnoremap <buffer> <silent> <M-e> :call <SID>menu_close()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>menu_open()<CR>
endfunction

function! s:menu_save() abort
  call s:save(filter(getline(1, '$'), 'v:val !~# "^\\s*$"'))
  setlocal nomodified
endfunction

function! s:menu_close() abort
  call s:menu_save()
  close
endfunction

function! s:menu_open() abort
  let file = getline('.')
  call s:menu_close()
  if !empty(file)
    execute 'edit' fnameescape(file)
  endif
endfunction
```

- [ ] **Step 5: Write `plugin/harpoon.vim`**

```vim
" harpoon.lua keys (Alt keys: plugin/terminal-keys.vim)
if !exists('g:myvim_tier') | finish | endif
nnoremap <silent> <leader>aa :call myvim#harpoon#add()<CR>
nnoremap <silent> <M-e> :call myvim#harpoon#menu()<CR>
nnoremap <silent> <M-h> :call myvim#harpoon#select(1)<CR>
nnoremap <silent> <M-j> :call myvim#harpoon#select(2)<CR>
nnoremap <silent> <M-k> :call myvim#harpoon#select(3)<CR>
nnoremap <silent> <M-l> :call myvim#harpoon#select(4)<CR>
nnoremap <silent> <M-p> :call myvim#harpoon#cycle(-1)<CR>
nnoremap <silent> <M-n> :call myvim#harpoon#cycle(1)<CR>
```

- [ ] **Step 6: Extend `tests/keytest.sh`** with a real Alt-key harpoon press. Before the `:qa!` line add:

```bash
T send-keys -t k Escape ':call myvim#harpoon#add()' Enter; sleep 0.5
T send-keys -t k Escape ':enew' Enter; sleep 0.5
T send-keys -t k M-h; sleep 0.5
w "expand('%:t')" h
```
and after the `jk` check add:
```bash
[ "$(cat $out.h)" = "$(basename $out.txt)" ] && echo "PASS <M-h> opens harpoon 1" || { echo "FAIL <M-h>: $(cat $out.h)"; fail=1; }
```

- [ ] **Step 7: Run, expect pass** (`run-matrix.sh bare keys rocky8 centos7`).

- [ ] **Step 8: Ship** (branch `task-10-harpoon`, message `Add a small harpoon with my-nvim's keys`).

---

### Task 11: Line blame

**Files:**
- Create: `plugin/blame.vim`, `autoload/myvim/blame.vim`, `tests/expect/75-blame.vim`

**Interfaces:**
- Produces: `myvim#blame#text()` (string for the cursor line, `''` outside git), `myvim#blame#update()`, `myvim#blame#clear()`, `myvim#blame#toggle()`.

- [ ] **Step 1: Branch** `task-11-blame`.

- [ ] **Step 2: Write the failing `tests/expect/75-blame.vim`**

```vim
" git-blame.nvim: ' <summary> • <date> • <author> • <<sha>>' for the cursor line
call ExpectMap('eval', 'n', '<Space>fgSt')
let s:repo = "call system('sh ' . shellescape(g:myvim_root . '/tests/samples/make-git-repo.sh') . ' /tmp/myvim-bl') | edit /tmp/myvim-bl/f.txt"
call Scenario('git', 'blame text for a committed line', [], s:repo, '', "myvim#blame#text() =~# '^ add-f • \\d\\d-\\d\\d-\\d\\d\\d\\d \\d\\d:\\d\\d:\\d\\d • Probe • <\\x\\{8}>$'", 1)
call Scenario('git', 'unsaved lines say Not Committed Yet', [], s:repo, 'Onew', 'myvim#blame#text()', ' Not Committed Yet')
call Scenario('eval', 'no blame outside git', ['x'], 'file /tmp/not-in-git.txt', '', 'myvim#blame#text()', '')
call Scenario('git', 'toggle turns it off', [], s:repo, "\<Space>fgSt", 'myvim#blame#text()', '')
" (the state is global: the scenario above left it off, this one turns it on again)
call Scenario('git', 'toggle again turns it back on', [], s:repo, "\<Space>fgSt", "myvim#blame#text() =~# 'add-f'", 1)
unlet s:repo
```
(The `Onew` scenario leaves the buffer modified; Scenario's `buffer!` handles it.)

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh bare rocky8`).

- [ ] **Step 4: Write `autoload/myvim/blame.vim`**

```vim
" Line blame (git-blame.nvim): after the cursor rests, the cursor line's
" commit as virtual text after the line (vim 9.0.1000+ with +textprop),
" echoed otherwise. On by default; <leader>fgSt toggles.
let s:on = 1
let s:vt = has('textprop') && has('patch-9.0.1000')
if s:vt
  silent! call prop_type_add('myvim_blame', {'highlight': 'Comment'})
endif

function! myvim#blame#text() abort
  let file = expand('%:p')
  if !s:on || &buftype !=# '' || empty(file) || !filereadable(file) || !executable('git')
    return ''
  endif
  let cmd = 'git -C ' . shellescape(fnamemodify(file, ':h')) . ' blame --porcelain --contents - -L '
        \ . line('.') . ',+1 -- ' . shellescape(file)
  let out = systemlist(cmd, getline(1, '$'))
  if v:shell_error || empty(out)
    return ''
  endif
  let sha = split(out[0])[0]
  if sha =~# '^0\+$'
    return ' Not Committed Yet'
  endif
  let info = {}
  for l in out[1:]
    let m = matchlist(l, '^\(\S\+\) \(.*\)$')
    if !empty(m)
      let info[m[1]] = m[2]
    endif
  endfor
  return printf(' %s • %s • %s • <%s>', get(info, 'summary', ''),
        \ strftime('%m-%d-%Y %H:%M:%S', str2nr(get(info, 'author-time', '0'))),
        \ get(info, 'author', ''), sha[:7])
endfunction

function! myvim#blame#clear() abort
  if s:vt
    silent! call prop_remove({'type': 'myvim_blame', 'all': 1})
  endif
endfunction

function! myvim#blame#update() abort
  call myvim#blame#clear()
  let text = myvim#blame#text()
  if empty(text)
    return
  endif
  if s:vt
    call prop_add(line('.'), 0, {'type': 'myvim_blame', 'text': text, 'text_align': 'after', 'text_padding_left': 1})
  else
    echo strpart(text, 0, &columns - 12)
  endif
endfunction

function! myvim#blame#toggle() abort
  let s:on = !s:on
  if s:on
    call myvim#blame#update()
  else
    call myvim#blame#clear()
  endif
  echo 'Line blame ' . (s:on ? 'on' : 'off')
endfunction
```
`systemlist()` with input arrives in 7.4.248, so all supported vims have it.

- [ ] **Step 5: Write `plugin/blame.vim`**

```vim
" git-blame.nvim: line blame when the cursor rests (updatetime=300)
if !exists('g:myvim_tier') | finish | endif
nnoremap <silent> <leader>fgSt :call myvim#blame#toggle()<CR>
augroup myvim_blame
  autocmd!
  autocmd CursorHold * call myvim#blame#update()
  autocmd CursorMoved,InsertEnter,BufLeave * call myvim#blame#clear()
augroup END
```

- [ ] **Step 6: Run, expect pass** (`run-matrix.sh bare rocky8 centos7`). On rocky8 (no virtual text) the same text is echoed; the probe checks only `myvim#blame#text()`.

- [ ] **Step 7: Ship** (branch `task-11-blame`, message `Add line blame like git-blame.nvim`).

---

### Task 12: LSP, completion, lint and format (tier 2)

**Files:**
- Create: `plugin/lsp.vim`, `autoload/myvim/lsp.vim`, `tests/expect/80-lsp.vim`

**Interfaces:**
- Consumes: `g:myvim_plugins` (vim-lsp, asyncomplete*, ale loaded), `myvim#complete#cr()`.
- Produces: `g:myvim_lsp_servers` (`{name: [filetypes]}` for servers found on PATH; the probe waits on it), `b:myvim_lsp` (set when a server attaches), `myvim#lsp#definition_in(where)`.

- [ ] **Step 1: Branch** `task-12-lsp`.

- [ ] **Step 2: Write the failing `tests/expect/80-lsp.vim`**

```vim
" lspconfig / nvim-cmp / nvim-lint / conform equivalents
call Expect('2', "type(get(g:, 'myvim_lsp_servers', 0))", type({}))
call ExpectMap('2', 'n', '<Space>ll')
call ExpectMap('2', 'n', '<Space>fm')
call ExpectMap('2', 'x', '<Space>fm')
call ExpectMap('2', 'n', '<Space>lspe')
call ExpectMap('2', 'n', '<Space>lsps')
call ExpectMap('2', 'n', '<Space>lspI')
call ExpectMap('2', 'i', '<C-e>')
call Expect('2', '&completeopt', 'menu,menuone,noselect')
" buffer-local keys once a server is attached to the first file
for s:m in ['gd', 'gD', 'gi', 'gr', 'K', 'gK', 'gl', 'gj', '<Space>pd', '<Space>pt', '<Space>pi',
      \ '<Space>pr', '<Space>pD', '<Space>pP', '<Space>D', '<Space>rn', '<Space>ca', '[d', ']d',
      \ '<Space>e', '<Space>q', '<Space>fls']
  call ExpectMap('lsp', 'n', s:m)
endfor
call ExpectMap('lsp', 'i', '<C-f>')
unlet s:m
call Expect('lsp:python', 'lsp#get_allowed_servers()', ['pyright'])
call Expect('lsp:yaml.ansible', 'lsp#get_allowed_servers()', ['ansiblels'])
call Expect('lsp:yaml.ansible', "get(b:, 'ale_linters', [])", ['ansible_lint'])
" ALE finds the trailing spaces in sample.yaml
call Scenario('ale', 'yamllint runs through ALE', [], "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/sample.yaml')", '',
      \ "WaitFor('len(ale#engine#GetLoclist(bufnr(\"%\"))) > 0', 20000)", 1)
" no tools on PATH: tier 2 still starts quietly and registers nothing
if !executable('pyright-langserver')
  call Expect('2', "has_key(g:myvim_lsp_servers, 'pyright')", 0)
endif
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh tools tools-ansible bare rocky9`).

- [ ] **Step 4: Write `plugin/lsp.vim`**

```vim
" Tier 2: vim-lsp (lspconfig), asyncomplete (nvim-cmp), ALE (nvim-lint and
" conform). Servers and tools are registered only when they are on PATH.
" This file loads before the plugins (plugin/ comes first in runtimepath),
" so their g: settings go here and the setup runs from their User events.
if !exists('g:myvim_tier') || g:myvim_tier < 2 || index(g:myvim_plugins, 'vim-lsp') < 0 | finish | endif

let g:myvim_lsp_servers = {}

" vim-lsp: diagnostics like my-nvim's vim.diagnostic.config
let g:lsp_diagnostics_virtual_text_enabled = 1
let g:lsp_diagnostics_virtual_text_align = 'after'
let g:lsp_diagnostics_echo_cursor = 1
let g:lsp_diagnostics_float_cursor = has('popupwin')
let g:lsp_document_highlight_enabled = 0
let g:lsp_signature_help_enabled = 1

" asyncomplete
let g:asyncomplete_auto_popup = 1
let g:asyncomplete_auto_completeopt = 0
set completeopt=menu,menuone,noselect

" ALE: lint and fix only; vim-lsp does the language servers
let g:ale_disable_lsp = 1
let g:ale_linters_explicit = 1
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_javascript_eslint_executable = 'eslint_d'
let g:ale_javascript_eslint_use_global = 1
let g:ale_linters = {
  \ 'javascript': ['eslint'], 'typescript': ['eslint'], 'javascriptreact': ['eslint'],
  \ 'typescriptreact': ['eslint'], 'svelte': ['eslint'],
  \ 'python': ['pylint'], 'yaml': ['yamllint'], 'ansible': ['ansible_lint'], 'sh': ['shellcheck'],
  \ }
let s:prettier = ['javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'svelte',
  \ 'css', 'html', 'json', 'yaml', 'markdown', 'graphql']
let g:ale_fixers = {}
for [s:tool, s:fts] in [['prettier', s:prettier], ['stylua', ['lua']], ['isort', ['python']], ['black', ['python']]]
  if executable(s:tool)
    for s:ft in s:fts
      let g:ale_fixers[s:ft] = get(g:ale_fixers, s:ft, []) + [s:tool]
    endfor
  endif
endfor
unlet! s:tool s:fts s:ft s:prettier

function! s:server(name, cmd, allow, ...) abort
  if !executable(a:cmd[0])
    return
  endif
  let info = {'name': a:name, 'cmd': a:cmd, 'allowlist': a:allow}
  if a:0
    call extend(info, a:1)
  endif
  call lsp#register_server(info)
  let g:myvim_lsp_servers[a:name] = a:allow
endfunction

function! s:setup() abort
  call s:server('pyright', ['pyright-langserver', '--stdio'], ['python'])
  call s:server('yamlls', ['yaml-language-server', '--stdio'], ['yaml'], {'blocklist': ['yaml.ansible']})
  call s:server('ansiblels', ['ansible-language-server', '--stdio'], ['yaml.ansible'])
  call s:server('bashls', ['bash-language-server', 'start'], ['sh', 'bash'])
  call s:server('lua_ls', ['lua-language-server'], ['lua'])
  call s:server('ts_ls', ['typescript-language-server', '--stdio'], ['javascript', 'javascriptreact', 'typescript', 'typescriptreact'])
  call s:server('html', ['vscode-html-language-server', '--stdio'], ['html'])
  call s:server('cssls', ['vscode-css-language-server', '--stdio'], ['css', 'scss', 'less'])
  call s:server('jsonls', ['vscode-json-language-server', '--stdio'], ['json'])
endfunction

function! s:on_buffer() abort
  let b:myvim_lsp = 1
  setlocal omnifunc=lsp#complete
  if exists('+tagfunc')
    setlocal tagfunc=lsp#tagfunc
  endif
  nmap <buffer> gd <plug>(lsp-definition)
  nmap <buffer> gD <plug>(lsp-declaration)
  nmap <buffer> gi <plug>(lsp-implementation)
  nmap <buffer> gr <plug>(lsp-references)
  nmap <buffer> K <plug>(lsp-hover)
  nmap <buffer> gK <plug>(lsp-signature-help)
  nnoremap <buffer> <silent> gl :call myvim#lsp#definition_in('right')<CR>
  nnoremap <buffer> <silent> gj :call myvim#lsp#definition_in('bottom')<CR>
  nmap <buffer> <leader>pd <plug>(lsp-peek-definition)
  nmap <buffer> <leader>pt <plug>(lsp-peek-type-definition)
  nmap <buffer> <leader>pi <plug>(lsp-peek-implementation)
  nmap <buffer> <leader>pD <plug>(lsp-peek-declaration)
  nmap <buffer> <leader>pr <plug>(lsp-references)
  nmap <buffer> <leader>pP <plug>(lsp-preview-close)
  imap <buffer> <C-f> <Esc><plug>(lsp-peek-definition)
  nmap <buffer> <leader>D <plug>(lsp-type-definition)
  nmap <buffer> <leader>rn <plug>(lsp-rename)
  nmap <buffer> <leader>ca <plug>(lsp-code-action)
  nmap <buffer> [d <plug>(lsp-previous-diagnostic)
  nmap <buffer> ]d <plug>(lsp-next-diagnostic)
  " vim-lsp has no single-line float command: both open the location list
  nmap <buffer> <leader>e <plug>(lsp-document-diagnostics)
  nmap <buffer> <leader>q <plug>(lsp-document-diagnostics)
  nmap <buffer> <leader>fls <plug>(lsp-document-symbol)
endfunction

function! s:complete_setup() abort
  call asyncomplete#register_source(asyncomplete#sources#buffer#get_source_options({
    \ 'name': 'buffer', 'allowlist': ['*'], 'completor': function('asyncomplete#sources#buffer#completor'),
    \ 'config': {'max_buffer_size': 5000000}}))
  call asyncomplete#register_source(asyncomplete#sources#file#get_source_options({
    \ 'name': 'file', 'allowlist': ['*'], 'priority': 10, 'completor': function('asyncomplete#sources#file#completor')}))
endfunction

augroup myvim_lsp
  autocmd!
  autocmd User lsp_setup call s:setup()
  autocmd User lsp_buffer_enabled call s:on_buffer()
  autocmd User asyncomplete_setup call s:complete_setup()
  " yaml.ansible: ansible-lint only (ALE would add yamllint for the yaml part)
  autocmd FileType yaml.ansible let b:ale_linters = ['ansible_lint']
augroup END

" global keys: ALE for buffers without a server, LSP start/stop/info
nnoremap <silent> <leader>ll :ALELint<CR>
nnoremap <silent> <leader>fm :ALEFix<CR>
" ALE fixes whole files; in visual mode too
xnoremap <silent> <leader>fm :<C-u>ALEFix<CR>
nmap [d <Plug>(ale_previous_wrap)
nmap ]d <Plug>(ale_next_wrap)
nnoremap <silent> <leader>e :ALEDetail<CR>
nnoremap <silent> <leader>lspe :call lsp#enable() <bar> edit<CR>
nnoremap <silent> <leader>lsps :LspStopServer<CR>
nnoremap <silent> <leader>lspI :LspStatus<CR>
inoremap <expr> <C-e> pumvisible() ? asyncomplete#cancel_popup() : "\<C-e>"
```

- [ ] **Step 5: Write `autoload/myvim/lsp.vim`**

```vim
" gl / gj (lspconfig.lua): the definition of the symbol under the cursor in
" the rightmost / lowest window, splitting when this is the only window there
function! s:edge_window(where) abort
  let best = win_getid()
  let bestpos = -1
  for w in range(1, winnr('$'))
    if getwinvar(w, '&buftype') !=# ''
      continue
    endif
    let pos = win_screenpos(w)[a:where ==# 'right' ? 1 : 0]
    if pos > bestpos
      let bestpos = pos
      let best = win_getid(w)
    endif
  endfor
  return best
endfunction

function! myvim#lsp#definition_in(where) abort
  let buf = bufnr('%')
  let pos = getcurpos()
  let target = s:edge_window(a:where)
  if target == win_getid()
    execute 'botright' (a:where ==# 'right' ? 'vsplit' : 'split')
  else
    call win_gotoid(target)
    execute 'buffer' buf
  endif
  call setpos('.', pos)
  LspDefinition
endfunction
```

- [ ] **Step 6: Run, expect pass** (`run-matrix.sh tools tools-ansible bare rocky9 rocky8`). `tools` must show `PASS LSP attached to sample.py`; `tools-ansible` shows `['ansiblels']` and `['ansible_lint']`. If `lsp#get_allowed_servers()` returns both `yamlls` and `ansiblels`, vim-lsp matches dotted filetypes by part: keep the `blocklist` and make it `['yaml.ansible', 'ansible']`, rerun.

- [ ] **Step 7: Check by hand once** in the VM with tools on PATH:
`ssh -t claude@$SRV 'PATH=/opt/myvim-tools/bin:$PATH tmux new vim ~/my-vim/tests/samples/sample.py'`: `K` on `greet` shows hover, `gd` on the call jumps, typing `gre` pops completion, `<CR>` without a selection inserts a newline. Write what you saw in the PR body.

- [ ] **Step 8: Ship** (branch `task-12-lsp`, message `LSP, completion, lint and format when the tools exist`).

---

### Task 13: install.sh, check.sh, README

**Files:**
- Create: `install.sh`, `check.sh`, `README.md`
- Modify: `tests/run-matrix.sh` (case `install`)

**Interfaces:**
- Consumes: everything; `tests/push.sh` and `tests/docker/run.sh` already call `install.sh` when it exists.

- [ ] **Step 1: Branch** `task-13-install`.

- [ ] **Step 2: Write the failing install test as a matrix case.** Add to `tests/run-matrix.sh`'s case list:

```bash
    install)       "$here/installtest.sh" ;;
```
add `install` to the default cases, and create `tests/installtest.sh`:

```bash
#!/bin/bash
# install.sh in a scratch HOME: existing ~/.vimrc and ~/.vim are moved aside,
# a rerun changes nothing, check.sh runs. Usage: tests/installtest.sh
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
h=$(mktemp -d); fail=0
mkdir -p "$h/.vim" && echo old > "$h/.vim/marker" && echo '" old' > "$h/.vimrc"
HOME=$h sh "$repo/install.sh" > "$h/out1" 2>&1 || { echo "FAIL install.sh exit $?"; fail=1; }
[ "$(readlink "$h/.vim")" = "$repo" ] && echo "PASS ~/.vim links to the repo" || { echo "FAIL link: $(ls -l "$h/.vim")"; fail=1; }
[ -f "$h/.vim.bak/marker" ] && echo "PASS old ~/.vim kept as ~/.vim.bak" || { echo "FAIL no ~/.vim.bak"; fail=1; }
[ -f "$h/.vimrc.bak" ] && [ ! -e "$h/.vimrc" ] && echo "PASS old ~/.vimrc moved aside" || { echo "FAIL ~/.vimrc"; fail=1; }
HOME=$h sh "$repo/install.sh" > "$h/out2" 2>&1
[ ! -e "$h/.vim.bak.1" ] && ! ls -A "$h" | grep -q 'bak\.' && echo "PASS rerun moves nothing" || { echo "FAIL rerun made backups"; fail=1; }
grep -q 'vim ' "$h/out1" && echo "PASS check.sh output shown" || { echo "FAIL no check.sh output"; cat "$h/out1"; fail=1; }
rm -rf "$h"
exit $fail
```

- [ ] **Step 3: Run, expect failure** (`run-matrix.sh install`: `install.sh` missing).

- [ ] **Step 4: Write `install.sh`**

```sh
#!/bin/sh
# Links ~/.vim to this repo (vim then reads ~/.vim/vimrc). Moves an existing
# ~/.vim to ~/.vim.bak and ~/.vimrc to ~/.vimrc.bak (~/.vimrc would win over
# ~/.vim/vimrc). Safe to rerun; no sudo, no network. Runs check.sh at the end.
set -eu
repo=$(cd "$(dirname "$0")" && pwd -P)
stamp=$(date +%Y%m%d-%H%M%S)

aside() {  # move $1 out of the way unless it already is the link to the repo
  if [ -L "$1" ] && [ "$(readlink "$1")" = "$repo" ]; then return 0; fi
  if [ -e "$1" ] || [ -L "$1" ]; then
    dest="$1.bak"
    [ -e "$dest" ] || [ -L "$dest" ] && dest="$1.bak.$stamp"
    mv "$1" "$dest"
    echo "moved $1 to $dest"
  fi
}

if [ "$repo" != "$(cd ~ && pwd -P)/.vim" ]; then
  aside "$HOME/.vim"
  [ -L "$HOME/.vim" ] || ln -s "$repo" "$HOME/.vim"
fi
aside "$HOME/.vimrc"
echo "my-vim: ~/.vim -> $repo"
sh "$repo/check.sh" || true
```

- [ ] **Step 5: Write `check.sh`**

```sh
#!/bin/sh
# Reports which vim this is, the my-vim tier it gets, the clipboard mode, and
# which optional tools are missing. Read-only. Exits with the number of
# problems (only a missing vim or a broken config count).
REPO_DIR=$(cd "$(dirname "$0")" && pwd)
PROBLEMS=0
ok()   { echo "  ok    $1"; }
note() { echo "  --    $1"; }
warn() { echo "  WARN  $1"; PROBLEMS=$((PROBLEMS + 1)); }

echo "Checking $(id -un)@$(uname -n)"
if ! command -v vim >/dev/null 2>&1; then
  warn "no vim on PATH"
  exit $PROBLEMS
fi
ok "vim $(vim --version | sed -n '1s/.*IMproved \([^ ]*\).*/\1/p') at $(command -v vim) ($(vim --version | sed -n 's/^Included patches: //p'))"

out=$(mktemp)
vim -Nu "$REPO_DIR/vimrc" -i NONE -es -c "call writefile([get(g:, 'myvim_tier', 'none'), get(g:, 'myvim_clip_mode', '?'), exists('##TextYankPost'), join(get(g:, 'myvim_plugins', []), ' ')], '$out')" -c 'qa!' </dev/null >/dev/null 2>&1
tier=$(sed -n 1p "$out" 2>/dev/null); clip=$(sed -n 2p "$out" 2>/dev/null)
yankpost=$(sed -n 3p "$out" 2>/dev/null); plugins=$(sed -n 4p "$out" 2>/dev/null)
rm -f "$out"
case $tier in
  2) ok "tier 2: plugins, LSP/lint when the tools below exist" ;;
  1) ok "tier 1: plugins; no LSP (needs vim 8.2+ with +job +timers)" ;;
  0) note "tier 0: options and keymaps only (vim has no packages)" ;;
  '') note "vim-tiny or no +eval: basic options only" ;;
  *) warn "config didn't load (tier '$tier')" ;;
esac
[ -n "$plugins" ] && ok "plugins: $plugins"
case $clip in
  tmux|osc52|system) ok "clipboard: $clip" ;;
  *) note "clipboard: $clip" ;;
esac
[ "$yankpost" = 0 ] && note "no TextYankPost (vim < 8.0.1394): yanks don't reach the clipboard; <leader>yy* and :MessagesToClipboard do"
if [ -n "${TMUX:-}" ]; then
  v=$(tmux -V 2>/dev/null)
  ok "$v"
  case $(tmux show -gv set-clipboard 2>/dev/null) in
    off) note "tmux set-clipboard is off: yanks reach the tmux buffer but not your terminal" ;;
  esac
fi
if command -v fzf >/dev/null 2>&1; then
  ok "fzf $(fzf --version | cut -d' ' -f1) (fzf.vim needs 0.63+, older uses ctrlp)"
else
  note "fzf not installed (ctrlp is used)"
fi
for t in rg git ctags; do
  command -v $t >/dev/null 2>&1 && ok "$t" || note "$t not installed (optional)"
done
for t in pyright-langserver yaml-language-server ansible-language-server bash-language-server \
         lua-language-server typescript-language-server vscode-html-language-server \
         vscode-css-language-server vscode-json-language-server \
         pylint ansible-lint yamllint shellcheck eslint_d prettier stylua black isort; do
  command -v $t >/dev/null 2>&1 && ok "$t" || note "$t not installed (optional)"
done
exit $PROBLEMS
```

- [ ] **Step 6: Write `README.md`**

````markdown
# my-vim

Vim configuration that brings [my-nvim](https://github.com/xepyon/my-nvim)'s
options, keymaps, look and plugin features to servers that only have vim.
Everything is in the repo (plugins are vendored), so it works without
internet.

## Install

```sh
git clone https://github.com/xepyon/my-vim.git ~/my-vim
sh ~/my-vim/install.sh
```

Without internet or git on the server (run on a machine that has the repo):

```sh
scp -r ~/my-vim user@server:my-vim
ssh user@server sh my-vim/install.sh
```

`install.sh` links `~/.vim` to the repo, moves an existing `~/.vim` and
`~/.vimrc` to `*.bak`, and runs `check.sh`. Safe to rerun; no sudo.
Update with `git -C ~/my-vim pull`.

`sh ~/my-vim/check.sh` shows the vim version, the tier it gets, the
clipboard mode and which optional tools are missing.

## What you get (tiers)

| vim | You get |
|-----|---------|
| `vi` / vim-tiny | numbers, tabs, search options; no errors |
| vim 7.4 without packages | options, keymaps, helpers (no plugins) |
| vim 8.0+ | plus the plugins: fuzzy finder, file tree, git, statusline, nightfly, undotree, tmux navigation, harpoon, line blame |
| vim 8.2+ with `+job` | plus LSP, completion, lint and format for the tools on `PATH` |

Language servers and linters are used only when installed; nothing is
installed for you.

## Clipboard

Yanks (`y`, `d`, `c` into the default register) go to your own machine's
clipboard, and `p` pastes it:

- **Inside tmux**: to the tmux buffer and, through tmux, to your terminal
  (OSC 52). `p` pastes the tmux buffer, so text copied in another pane or
  on your machine pastes too.
- **Without tmux**: OSC 52 straight to your terminal; paste from your
  machine with the terminal's paste key.
- `x` and `dd` don't touch the clipboard (`dd` keeps the line in register 9).

Your terminal must allow OSC 52 (WezTerm, iTerm2, kitty, Alacritty, Windows
Terminal do). In tmux, `set-clipboard` must not be `off`. Over **mosh**,
tmux must send `52;c;` (my-tmux's config does; tmux's default doesn't).

## Keymaps

Leader is `Space`. Same keys as my-nvim; the full list is in
`docs/superpowers/specs/2026-10-10-nvim-to-vim-port-design.md` ("Keymaps").
The most used: `<leader>ff` files, `<leader>fs` grep, `<leader>fb` buffers,
`<leader>ee` tree, `<leader>aa` / `Alt-h/j/k/l` harpoon, `<leader>ut`
undotree, `<leader>sm` maximize, `gd` / `K` / `gr` / `<leader>rn` /
`<leader>ca` LSP, `<leader>ll` lint, `<leader>fm` format, `<leader>fgSt`
line blame.

## Development

Plugins are pinned in `plugins.list`; `./update-plugins.sh --bump` moves
them to their latest commits (dev machine only, then test and commit).
Tests run on throwaway VMs and containers: see `.claude/CLAUDE.md`.
````

- [ ] **Step 7: Run, expect pass** (`run-matrix.sh` all cases, including `install`). Also run `ssh claude@$SRV 'sh ~/my-vim/check.sh; PATH=/opt/myvim-tools/bin:$PATH sh ~/my-vim/check.sh'` and paste both outputs in the PR body.

- [ ] **Step 8: Offline install check.** On the server VM, block outgoing traffic except ssh and scp the repo from the client:

```bash
ssh claude@$SRV 'sudo iptables -I OUTPUT -o lo -j ACCEPT; sudo iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT; sudo iptables -A OUTPUT -j REJECT; rm -rf ~/my-vim ~/.vim'
tar --exclude=.git --exclude=.state -cf - . | ssh claude@$SRV 'mkdir ~/my-vim && tar -x -C ~/my-vim && sh ~/my-vim/install.sh && bash ~/my-vim/tests/run-matrix.sh bare'
ssh claude@$SRV 'sudo iptables -F OUTPUT'
```
Expected: `PASS bare` with no network.

- [ ] **Step 9: Ship** (branch `task-13-install`, message `Add install.sh, check.sh and README`).

---

### Task 14: Full run, docs for the next session, baseline

**Files:**
- Modify: `.claude/CLAUDE.md` (append the testing section)

- [ ] **Step 1: Branch** `task-14-docs`.

- [ ] **Step 2: Revert both VMs to `base-harness`, push `main`, run everything**

```bash
pwsh -NoProfile -Command '. ~/projects/vibe-powercli/scripts/vc-connect.ps1; foreach ($n in "my-vim-test01","my-vim-client01") { Set-VM -VM (Get-VM $n) -Snapshot (Get-Snapshot -VM $n -Name base-harness) -Confirm:$false | Out-Null; Start-VM $n | Out-Null }'
sleep 60
git checkout main && tests/push.sh claude@$SRV && ssh claude@$SRV 'bash ~/my-vim/tests/run-matrix.sh'
```
Then rerun Task 6 Step 10 (the eight chains). Expected: every case PASS and the chain table as in Task 6.

- [ ] **Step 3: Append the testing section to `.claude/CLAUDE.md`**

```markdown
## Testing in VMs (homelab vCenter)

Never install this config on the dev machine (`install.sh` replaces
`~/.vim`). Test on throwaway VMs created through `~/projects/vibe-powercli`
(rules there: folder, datastore, network, snapshots, hands-off VMs).

@~/projects/vibe-powercli/.claude/CLAUDE.md

- VMs: `my-vim-test01` (template `docker-host-*`, user `claude`) runs the
  probes and the Docker images with old vims; `my-vim-client01`
  (`ubuntu-2404-base-*`) is the "user's terminal" for the clipboard chains.
  Both have snapshot `base-harness` (tools in `/opt/myvim-tools`, images
  `myvim-test:*`, my-tmux, client key in the server's authorized_keys).
  Their IPs are in `.claude/vms.local` (git-ignored: the repo is public).
- Loop: `tests/push.sh claude@$SRV && ssh claude@$SRV 'bash ~/my-vim/tests/run-matrix.sh [CASE...]'`.
  Cases and what they cover: header of `tests/run-matrix.sh`. A check is a
  line in `tests/expect/*.vim` (`Expect`, `ExpectMap`, `Scenario`; API at the
  top of `tests/probe.vim`). Write the failing line first.
- Clipboard chains: Task 6 Step 10 of
  `docs/superpowers/plans/2026-10-10-nvim-to-vim-port.md` has the commands
  and the expected table. Run them for any change to clipboard, tmux
  escapes or key handling.
- Harness pitfalls (from my-nvim): a killed vim leaves a swap file (E325
  next run); `script` needs a pty size (`stty rows 40 cols 160`) or mosh
  aborts; my-tmux's display-message opens view mode over a new server's
  first pane (`remote.sh ready` cancels it); `pkill -f` matches its own shell.
```

- [ ] **Step 4: Refresh the baseline**: power off both VMs, take snapshot `baseline-main-<short sha>`, delete `base-harness` only if the new one is good, power on.

- [ ] **Step 5: Ship** (branch `task-14-docs`, message `Document the VM test loop`). Then tell the user the fork is ready and offer "send to xepyon" (the release PR is theirs to merge).
