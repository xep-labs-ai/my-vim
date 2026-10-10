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
- `x` and `dd` don't touch the clipboard (`dd` still fills the numbered
  registers, so `"1p` brings the line back).

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
