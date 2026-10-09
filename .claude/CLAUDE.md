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
