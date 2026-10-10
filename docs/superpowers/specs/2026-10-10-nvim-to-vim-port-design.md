# Port my-nvim to vim: design

Date: 2026-10-10. Source config: `~/projects/my-nvim` (`main` e6c8f1b).

## Goal

Many servers the user connects to have vim but not nvim. This repo gives vim
as much of my-nvim's behaviour and muscle memory as possible: the same
options, the same keymaps, the same look, and the same plugin features where
vim has an equivalent.

## Constraints (from the user)

- Servers are **mixed / unknown**: some have internet and git, some don't;
  vim versions vary (vim-tiny, RHEL-style vim 8.x, Ubuntu vim 9.x).
- **Layered features**: when a language server or lint tool exists on the
  server, use it (LSP, completion, linting); when it doesn't, fall back to the
  plain editing setup. No errors and no "Press ENTER" prompts either way.
- **Plugins are vendored** in the repo, so `git clone` or `scp -r` alone gives
  the full setup with no network access.
- The repo is public: no secrets, hostnames or machine-specific paths.

## Success criteria

1. On vim 8.0+ every keymap in "Keymaps" below that is not marked
   LSP-only works, with no startup messages.
2. On vim 8.2+ with `+job`/`+timers`, opening a file whose language server is
   on `PATH` attaches it, and the LSP keymaps work; without the server the
   same file opens silently.
3. On vim-tiny / a build without `+eval`, `vim` starts with no errors.
4. A server with no internet gets the full setup from `scp -r`.
5. All of the above verified in VMs (see "Testing").

## Feature tiers

Decided at startup, per server and per filetype; nothing is configured by
hand on the server.

| Tier | Condition | What loads |
|------|-----------|------------|
| 0 | no `+eval` (vim-tiny, `vi`) | Only plain `set` options outside `if 1`; everything else is skipped |
| 1 | vim 8.0+ (`has('packages')`) | All options, keymaps, own scripts, `pack/vendor/start` plugins |
| 2 | tier 1 + `has('job') && has('timers') && v:version >= 802` | `packadd` vim-lsp, asyncomplete and ALE; servers/linters registered only if `executable()` |
| + | `executable('fzf')` | `packadd` fzf + fzf.vim; otherwise ctrlp.vim serves the same keys |
| + | `executable('ctags')` or LSP attached | vista.vim outline has a source |

Vim 7.4 (old RHEL 7) has no `packages`: it gets the tier-0 options and the
own `plugin/*.vim` files (options, keymaps, scripts), but no vendored
plugins, and `plugin/plugins.vim` skips plugin mappings there. Best effort:
tested only for "starts without errors" if a 7.4 build is easy to get.

## Layout

The repo is `~/.vim` (`install.sh` links it, like my-nvim links to
`~/.config/nvim`). vim 7.4+ reads `~/.vim/vimrc`, so no `~/.vimrc` is needed.

```
vimrc                  Entry point. Tier-0 `set` lines first, then `if 1 ... endif`
                       around everything that needs +eval (vim-tiny skips it).
                       Sets <Space> leader, then lets plugin/ and pack/ load.
plugin/                Own config, one file per topic, mirroring my-nvim's core/:
  options.vim            core/options.lua (+ help/preview window autocmds)
  keymaps.vim            core/keymaps.lua + vimscript/keymaps.vim
  scripts.vim            core/scripts.lua (F5 toggle, preview scroll, :MessagesToClipboard,
                         swap-file prompt)
  ansible.vim            core/ansible.lua (yaml.ansible filetype, gf to role tasks)
  plugins.vim            settings + keymaps for vendored plugins (NERDTree, fzf/ctrlp, ...)
  lsp.vim                tier 2 only: packadd, server registration, LSP keymaps
  harpoon.vim            own small harpoon replacement (see below)
  terminal-keys.vim      <M-x> key definitions for terminal vim
autoload/              Lazily-loaded functions used by the files above
pack/vendor/opt/       All vendored plugins; vimrc's plugin table `packadd!`s each one
                       by condition (tier, fzf version, or a vim version a plugin needs)
plugins.list           One line per vendored plugin: name, repo URL, pinned commit,
                       optional git pathspecs (to leave out tests and the like)
update-plugins.sh      Re-vendors every plugin in plugins.list (git archive of the pinned
                       ref, .git stripped). Run on the dev machine only.
install.sh             Links ~/.vim to the repo (moves an existing ~/.vim to ~/.vim.bak and
                       ~/.vimrc to ~/.vimrc.bak, since ~/.vimrc wins over ~/.vim/vimrc),
                       creates ~/.vim-undo etc. Safe to rerun; no sudo, no network.
check.sh               Reports the vim version, tier, and which optional tools
                       (fzf, ctags, rg, language servers, linters, formatters) are missing.
tests/                 VM probes (see Testing)
README.md              Quickstart (git clone / scp), tiers, keymap list
```

State files (undo, swap, viminfo) go under `~/.vim/.state/` (git-ignored) so
the repo directory stays clean and nothing lands in the working directory.

## Mapping from my-nvim

### Options (core/options.lua)

Ported 1:1: `relativenumber number tabstop=2 shiftwidth=2 expandtab
autoindent wrap ignorecase smartcase cursorline scrolloff=999
background=dark signcolumn=auto backspace=indent,eol,start splitright
splitbelow iskeyword+=- title undofile`.

Adapted:
- `termguicolors` only when `has('termguicolors')` and the terminal has
  256+ colours (`&t_Co >= 256`, i.e. not the Linux console); inside tmux
  (`$TERM` is `screen*`/`tmux*`) also set `t_8f`/`t_8b`, which vim only
  sets by itself for `xterm*`.
- Clipboard: see "Clipboard and tmux" below.
- `winbar` has no vim equivalent: the file name goes in the statusline.
- Help window height and "move preview window to the right" autocmds: same
  logic in vimscript (`BufWinEnter` + `&ft ==# 'help'`, `WinEnter` +
  `&previewwindow`).
- Folding (nvim-ufo): `foldmethod=indent foldlevel=99 foldlevelstart=99`
  plus the nightfly fill chars; no ufo-style preview.
- Plus the vim defaults nvim gives for free: `nocompatible`, `filetype
  plugin indent on`, `syntax on`, `incsearch hlsearch`, `laststatus=2`,
  `wildmenu`, `ttimeout ttimeoutlen=50`, `encoding=utf-8`, `hidden`,
  `autoread`, `belloff=all`, `mouse=nvi`, `display=lastline`,
  `nrformats=bin,hex`, `nostartofline`, `history=10000`, `smarttab`,
  `formatoptions=tcqj`, `nojoinspaces`, `Y` = `y$`, and nvim's cursor
  shapes (bar in insert, underline in replace).
- Terminal escapes vim only sets for `xterm*` but tmux needs: bracketed
  paste (`t_BE t_BD t_PS t_PE`, so pasting into insert mode doesn't
  auto-indent every line), focus events (`t_fe t_fd`, for `autoread` and
  gitgutter when switching panes), `ttymouse=sgr`.

## Clipboard and tmux

This is the most important part to get right: the user yanks in vim on a
server, usually inside tmux, and pastes on their own machine, and the other
way round. It must behave like my-nvim's `clipboard=unnamedplus` with nvim's
tmux provider (see my-nvim's CLAUDE.md, "Clipboard over SSH/mosh + tmux").

The mode is picked once at startup (`g:myvim_clip_mode`):

| Mode | When | Yank (`y d c` to the unnamed register, `<leader>yy*`, `:MessagesToClipboard`) | `p P gp gP` (unnamed register) |
|------|------|-------------------------|------------------------|
| `system` | `has('clipboard')` and (`$DISPLAY`, `$WAYLAND_DISPLAY` or macOS) | `clipboard=unnamedplus`, vim does it | vim does it |
| `tmux` | `$TMUX` set and `tmux` on PATH | `tmux load-buffer -w -` (tmux 3.2+: buffer + OSC 52 to the client through tmux's `set-clipboard`); older tmux: `load-buffer -` plus an OSC 52 wrapped in tmux passthrough | first `tmux refresh-client -l` (3.2+, asks the client terminal for its clipboard), then the unnamed register is set from `tmux save-buffer -`, so text copied in another pane or on the client pastes with `p` |
| `osc52` | anything else in a terminal (no tmux, or tmux whose `$TMUX` was lost, e.g. `sudo`) | OSC 52 `ESC]52;c;<base64>BEL` written to the terminal (`echoraw()`, else `/dev/tty`) | vim's own register; paste from the client with the terminal's paste key |

- Only what `unnamedplus` would copy is synced: yanks/deletes into the
  unnamed register. `x` (`"_x`), `dd` (`"9dd`) and visual `<CR>` (`"hy`)
  don't touch the clipboard, and `p` after them pastes the clipboard, as in
  nvim.
- When the tmux buffer holds exactly what vim last sent, `p` keeps vim's own
  register (so blockwise yanks stay blockwise).
- The selection parameter is always `c`: mosh only forwards `52;c;`.
- Yank sync needs `TextYankPost` (vim 8.0.1394+); older vims get the
  `<leader>yy*` keys and `:MessagesToClipboard` only. `check.sh` says so.
- With a tmux that has no my-tmux config, mosh can't carry tmux's OSC 52
  (tmux sends `52;;`); ssh works. That's a tmux setting, documented in the
  README, not something vim can fix.

### Keymaps

Leader is `<Space>` in all cases.

Ported unchanged (tier 1):

| Keys | Action | From |
|------|--------|------|
| `jk` (i) | Esc | keymaps.lua |
| `<leader>hn` | `:nohl` | keymaps.lua |
| `<leader>+` / `<leader>-` | `<C-a>` / `<C-x>` | keymaps.lua |
| `<leader>sv sh se sx` | split v / h / equalize / close | keymaps.lua |
| `<leader>to tx tn tp` | tab new / close / next / prev | keymaps.lua |
| `<leader>1`..`9` | go to tab N | keymaps.vim |
| `<C-W>{{` | `PeditVertical()` | keymaps.lua |
| `x` / `dd` | `"_x` / `"9dd` | keymaps.vim |
| `<C-r>` / `<C-e>` (v) | replace selection with / without confirm | keymaps.vim |
| `<leader>o` / `<leader>O` | blank line below / above | keymaps.vim |
| `<leader>hh` | highlight word under cursor, no jump | keymaps.vim |
| `<CR>` (x) | highlight visual selection | keymaps.vim |
| `<C-c>` | toggle `hlsearch` | keymaps.vim |
| `<leader>yyr yyp yyf` | copy relative / full path / file name | keymaps.vim |
| `<M-,>` / `<M-.>` | vertical resize -2 / +2 | keymaps.vim |
| `<F5>` | toggle line numbers | scripts.lua |
| `<C-P><C-D>` / `<C-P><C-U>` | scroll preview window | scripts.lua |
| `<leader>hi` | show syntax groups under cursor (`synstack`) | scripts.lua (`:Inspect`) |
| `:MessagesToClipboard` | messages to `+`/OSC 52 and a scratch buffer | scripts.lua |
| `gf` in yaml.ansible | jump to `roles/<role>/tasks/<file>` | ansible.lua |

Plugin keymaps (tier 1, same keys as my-nvim):

| Keys | vim implementation | nvim plugin |
|------|--------------------|-------------|
| `<leader>ff fs fc fb fh fht fe fF fg fgf` | fzf.vim `:Files :Rg :Rg <cword> :Buffers :Helptags :BLines :Files`(hidden) `:GFiles`; ctrlp fallback for files/buffers, `:vimgrep`/`grepprg` for grep | telescope |
| `<leader>fgs fgb fgc` | fzf.vim `:GFiles? `, fugitive `:Git branch`, `:Commits` | telescope git |
| `<leader>fu` | undotree | telescope-undo |
| `<leader>ee ef ec er ea` | NERDTree toggle / find / collapse / refresh / expand all | nvim-tree |
| `<leader>ut up`, `uc` | undotree toggle / persist / clear | undotree |
| `<leader>sm` | `:MaximizerToggle` | vim-maximizer |
| `<C-h/j/k/l>` | vim-tmux-navigator | same |
| `gc`, `gcc` | vim-commentary | Comment.nvim |
| `ys cs ds` | vim-surround | same |
| `gr{motion}` | ReplaceWithRegister | same |
| `<leader>fgSt` | gitgutter + `:Git blame` line toggle | gitsigns |
| `<leader>aa`, `<M-e>`, `<M-h/j/k/l>`, `<M-p>/<M-n>` | own harpoon.vim | harpoon |
| `<leader>mo mf` | vista.vim toggle / follow | outline.nvim |
| `<leader>ttt` / `<leader>ttv` | `:tab terminal` / `:botright terminal` (vim 8.1+) | toggleterm |
| `<C-h/j/k/l>` in terminal | `tnoremap` to `<C-w>h` etc. | toggleterm |

LSP / lint / format keymaps (tier 2, buffer-local, only set when a server
attaches or ALE has a tool for the filetype):

| Keys | vim implementation | nvim |
|------|--------------------|------|
| `gd gD gi gr K gK` | `:LspDefinition :LspDeclaration :LspImplementation :LspReferences :LspHover :LspSignatureHelp` | lspconfig |
| `gl` / `gj` | definition in the rightmost / lowest split (own function around vim-lsp) | lspconfig |
| `<leader>pd pt pi pr pD` | `:LspPeekDefinition` etc. (vim-lsp preview popup) | goto-preview |
| `<leader>pP` | close preview/popups | goto-preview |
| `<space>rn`, `<space>ca` | `:LspRename`, `:LspCodeAction` | lspconfig |
| `<space>D` | type definition | lspconfig |
| `<space>e`, `[d`, `]d`, `<space>q` | `:LspDocumentDiagnostics`/ALE detail, next/prev diagnostic, location list | diagnostics |
| `<space>lspe lsps lspI` | start / stop / `:LspStatus` | lspconfig |
| `<leader>fls` | `:LspDocumentSymbol` | telescope lsp |
| `<leader>ll` | `:ALELint` | nvim-lint |
| `<leader>fm` (n, v) | `:ALEFix` | conform |
| completion `<C-n> <C-p> <C-e> <C-y> <CR>` | asyncomplete with the same keys | nvim-cmp |

### Language tools (tier 2)

Registered only when the executable exists; the list mirrors my-nvim's Mason
set where the tool is plausible on a server:

- LSP (vim-lsp): `pyright-langserver`, `yaml-language-server`,
  `ansible-language-server` (yaml.ansible), `bash-language-server`,
  `lua-language-server`, `typescript-language-server`,
  `vscode-{html,css,json}-language-server`.
- Linters (ALE): `pylint`, `ansible-lint`, `yamllint`, `shellcheck`,
  `eslint_d`.
- Fixers (ALE): `prettier`, `stylua`, `black`/`isort` if present.

ALE runs as linter/fixer only (`g:ale_disable_lsp = 1`) so it never fights
vim-lsp. Nothing is installed on servers; `check.sh` lists what's missing.

### Plugins vendored

| Plugin | Loads at | Replaces |
|--------|-----|----------|
| bluz71/vim-nightfly-colors | tier 1 | same (vim build), + CursorLine `#202d69` override |
| tpope/vim-fugitive | tier 1 | fugitive, neogit, diffview |
| tpope/vim-surround | tier 1 | same |
| tpope/vim-commentary | tier 1 | Comment.nvim |
| tpope/vim-repeat | tier 1 | (needed by surround/commentary repeat) |
| vim-scripts/ReplaceWithRegister | tier 1 | same |
| christoomey/vim-tmux-navigator | tier 1 | same |
| mbbill/undotree | tier 1 | undotree, telescope-undo |
| szw/vim-maximizer | tier 1 | same |
| preservim/nerdtree | tier 1 | nvim-tree |
| airblade/vim-gitgutter | tier 1 | gitsigns |
| itchyny/lightline.vim | tier 1 | lualine (colours from lualine.lua) and bufferline (which runs in `mode = "tabs"`: lightline's own tabline) |
| jiangmiao/auto-pairs | tier 1 | nvim-autopairs |
| Yggdroot/indentLine | tier 1 | indent-blankline (one colour, not rainbow; off for json/markdown/help, where its `conceal` would hide quotes) |
| ctrlpvim/ctrlp.vim | tier 1 | telescope fallback |
| liuchengxu/vista.vim | tier 1 | outline.nvim |
| junegunn/fzf (vim plugin part only) + junegunn/fzf.vim | tier 1 with fzf 0.63+ | telescope |
| prabirshrestha/vim-lsp | tier 2 | lspconfig |
| prabirshrestha/asyncomplete.vim + asyncomplete-lsp.vim + asyncomplete-buffer.vim + asyncomplete-file.vim | tier 2 | nvim-cmp sources |
| dense-analysis/ale | tier 2 | nvim-lint, conform |

Each pinned to a commit in `plugins.list` (many of these projects tag rarely,
so commits, not tags). Licences (MIT / Vim / Apache) are kept in each plugin dir.

### Own harpoon replacement

`plugin/harpoon.vim` + `autoload/harpoon.vim`, ~60 lines: a per-project list
(project = git root, else cwd) stored in `~/.vim/.state/harpoon/<hash>`.
`<leader>aa` adds the current file, `<M-e>` opens the list in a small split
buffer you edit like text (reorder/delete lines, `:w` or `q` saves),
`<M-h/j/k/l>` open entries 1-4, `<M-p>/<M-n>` previous/next.

### Line blame (git-blame.nvim)

On by default like git-blame.nvim, toggled with `<leader>fgSt`: after the
cursor rests (`updatetime=300`), ` <summary> • <date> • <author> • <<sha>>`
for the cursor line, as virtual text after the line on vim 9.0.1000+ with
`+textprop`, echoed otherwise. `git blame --contents -` so unsaved edits
don't shift it.

### Not ported

treesitter (vim syntax files instead), nvim-ufo, render-markdown,
CopilotChat, copilot.vim (needs Node and a GitHub login per server),
neogit/diffview (fugitive covers it), which-key, cheatsheet, lsp_signature
(`gK` covers it), nvim-web-devicons (no Nerd Font guaranteed on the
client path), LSP workspace-folder keys (`<space>wa wr wl`: vim-lsp has no
commands for them), Mason (nothing is installed on servers), the telescope-specific
`gL` picker.

## Terminal key handling

- `<M-x>` keys: terminal vim receives `Esc x`. `plugin/terminal-keys.vim`
  runs `execute "set <M-h>=\eh"` (and j k l e p n , .) when not in the GUI,
  with `ttimeoutlen=50` so a real Esc isn't delayed and `jk` still works.
- `<C-s>`: not mapped in vim (copilot's mapping is gone); no `stty -ixon`.
- `<C-c>` toggles hlsearch in normal mode only, as in nvim.
- Inside tmux, `xterm-keys` / `extended-keys` aren't assumed.

## Testing

Same approach as my-nvim: throwaway VMs in the homelab vCenter through
`~/projects/vibe-powercli`, in folder `ClaudeCode-Host71`, named
`my-vim-test-<x>`, on `VM Network`. Never test `install.sh` on the dev
machine (it replaces `~/.vim`).

Matrix:

| Case | VM | Checks |
|------|----|--------|
| A: modern, tools | Ubuntu 24.04 (vim 9.1), pyright, yaml-language-server, shellcheck, yamllint, fzf, ripgrep, ctags | all tiers, LSP attach, ALE, fzf keys |
| B: modern, bare | same VM, snapshot before tools | tier 1 only, ctrlp fallback, no LSP messages |
| C: old vims | Docker containers on case B's VM (the `docker-host` template; there is no RHEL template): Rocky 8 (vim 8.0, tmux 2.7), Rocky 9 (vim 8.2, tmux 3.2a), Ubuntu 16.04 (vim 7.4.1689, has `packages`), CentOS 7 (vim 7.4.629, no `packages`) | right tier, no errors |
| D: tiny | Debian 12 container with only `vim-tiny` | starts with no errors |
| E: offline | case B with the default route removed, repo copied with `scp -r` | same as B |

Probes in `tests/`:
- `probe.vim`: run as `vim -Nu ~/.vim/vimrc -c 'source probe.vim'` inside
  tmux; opens sample files (py, yaml, ansible role, sh, md), waits for LSP,
  writes `:messages`, `v:errmsg`, tier, the result of `maparg()` for every
  keymap in this spec, and attached LSP servers to a file.
- Screen check: `tmux new-session -d -x 200 -y 50 "vim ..."`, then
  `tmux capture-pane -p` to catch "Press ENTER" and E-errors that
  `:messages` misses.
- Snapshots per VM after the base install, so reruns revert instead of
  recloning.

Clipboard chains (run from a second VM, `my-vim-client01`, with tmux, mosh
and my-tmux, using my-nvim's `cliptest` harness adapted for vim): yank on
the server must reach the server's tmux buffer and the client terminal as
OSC 52, and `p` must paste the tmux buffer (also text set by another pane):

1. ssh → tmux → vim
2. mosh → tmux → vim
3. client tmux → ssh → tmux → vim
4. client tmux → mosh → tmux → vim
5. ssh → vim (no tmux; OSC 52 straight to the terminal)
6. ssh → tmux → `env -u TMUX vim` (tmux lost from the environment)
7. ssh → tmux with no config (`-f /dev/null`) → vim
8. ssh → Rocky 8 container: tmux 2.7 → vim 8.0 (old-tmux path, no `echoraw()`)

## Out of scope (for now)

- Hooking my-vim into my-zsh's `install.sh`.
- Installing language servers or tools on servers.
- GUI vim (gvim/MacVim) specifics.
- Keeping my-vim in sync with future my-nvim changes automatically
  (done by hand per change).
