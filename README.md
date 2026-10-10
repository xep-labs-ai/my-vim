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

### Smaller copies: `vim_tiny` and `vim_small`

For servers where you only want the essentials. On a machine with the repo:

```sh
sh install_tiny.sh     # builds vim_tiny/  (~0.6 MB)
sh install_small.sh    # builds vim_small/ (~4 MB)
scp -r vim_small user@server:.vim     # the server must have no ~/.vim yet
ssh user@server sh .vim/install.sh    # moves ~/.vimrc aside, runs check.sh
```

Both have the whole config (options, keymaps, clipboard through tmux, harpoon,
line blame) and only these plugins, most important first:

| | Plugins |
|---|---|
| tiny | vim-tmux-navigator, vim-commentary, vim-surround, vim-repeat, ReplaceWithRegister, ctrlp.vim |
| small | tiny plus nerdtree, lightline.vim, vim-fugitive, vim-gitgutter, undotree, vim-maximizer, vim-nightfly-colors, indentLine, auto-pairs |

No LSP, completion, lint or fzf (they need tools an offline server won't
have). `sh ~/.vim/check.sh` on the server says which bundle it is, which of
its plugins that vim skips and why, and warns when a `~/.vimrc` would keep
vim from reading `~/.vim/vimrc`.

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
- vim older than 8.0.1394 (CentOS 7, Ubuntu 16.04) has no yank event:
  yanks stay in vim and `p` pastes them as usual; `<leader>yyr/yyp/yyf` and
  `:MessagesToClipboard` still copy.
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
