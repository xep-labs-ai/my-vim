# CLAUDE.md: my-vim

Personal vim configuration.

## Contributing upstream (xepyon)

`origin` = xep-labs-ai/my-vim, the fork where all work happens; `upstream` =
xepyon/my-vim. **Claude runs this whole flow by default. The user's only job is
merging the release PR in xepyon when they ask for one.**

1. **Each change:** `git fetch origin && git checkout -b <branch> origin/main`
   (never commit to `main`). Commit, test, `git push -u origin <branch>`, open
   a PR into xep-labs-ai/my-vim, and merge it (Claude merges in the fork).
   Repeat per change; nothing goes to xepyon yet.
2. **When the user says "send to xepyon":** `git fetch --multiple origin upstream`,
   check `git log --oneline upstream/main..origin/main` isn't empty and no
   xepyon PR is open, then snapshot the fork and open one PR from the
   snapshot, never from `main` (a PR from `main` picks up every later merge):
   `git push origin origin/main:refs/heads/release/<yyyy-mm-dd>`, then
   `gh pr create --repo xepyon/my-vim --base main --head
   xep-labs-ai:release/<yyyy-mm-dd>`, listing the fork PRs it contains.
3. **The user merges it in xepyon.** Watch the PR so step 4 starts without
   being asked.
4. **Sync:** `gh repo sync xep-labs-ai/my-vim --source xepyon/my-vim`
   (fast-forward), fast-forward local `main`, delete the release branch and
   the merged change branches (local and origin). If the fork merged more
   after the snapshot, bring xepyon's merge commit in through a fork PR that
   merges `upstream/main` instead. If xepyon squash-merged, ask before
   resetting anything.

Stop and ask instead when local `main` has unpushed commits, a branch isn't
fully merged, a merge has conflicts, or another session owns the change.
Never push to or merge in xepyon.

Notes for this repo:
- `xepyon/my-vim` is the main repo; real machines only get changes the user
  merged there.
- Both repos are **public** (GitHub doesn't allow a private fork of a public
  repo), unlike my-zsh. Never commit secrets, hostnames or machine-specific
  paths.
- Opening PRs against `xepyon/my-zsh` was once blocked by Claude Code's
  auto-mode classifier; if that happens here, give the user the
  `gh pr create` command to run with `!`.

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
- Pitfalls found while building this (2026-10-10):
  - The probe's VimEnter autocmd must be `nested`, or no autocmd fires
    inside the checks; `:normal` drops a leading space (a `<Space>` leader),
    so Scenario puts an `<Esc>` first.
  - A changed sample buffer leaves a swap file when vim is killed: checks
    use their own files in /tmp, and run-probe quits vim before the kill.
  - vim < 8.2 keeps `v:register` (`_`, `9`) for the command after a mapping
    that used it: `x`/`dd` reset it with `""<Esc>` there.
  - tmux 1.x hangs on `load-buffer -` when stdin is a file (how `system()`
    feeds it); vim 7.4's `mkdir(..., 'p')` fails (E739) on a directory that
    exists.
  - Plugins that break old vims get a condition in vimrc's `s:want` table
    (vim-tmux-navigator: `:tnoremap`; nightfly: `+termguicolors`).
