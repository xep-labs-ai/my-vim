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
pack/vendor/start/     Plugins for tier 1
pack/vendor/opt/       Plugins loaded conditionally (vim-lsp, asyncomplete*, ALE, fzf.vim)
plugins.list           One line per vendored plugin: name, repo URL, pinned tag/commit, start|opt
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
- `termguicolors` only when `has('termguicolors')` and the terminal is
  not a bare console (`$COLORTERM` or `$TERM =~ 256color`), else 256 colors.
- `clipboard`: `unnamedplus` only when `has('clipboard')` (servers usually
  have `-clipboard`). Without it, yank to the client goes through OSC 52:
  a `TextYankPost` autocmd (vim 8.0.1394+) sends the unnamed register as
  OSC 52, wrapped for tmux (`\ePtmux;` passthrough) when `$TMUX` is set.
  `<leader>yy*` use the same path.
- `winbar` has no vim equivalent: the file name goes in the statusline.
- Help window height and "move preview window to the right" autocmds: same
  logic in vimscript (`BufWinEnter` + `&ft ==# 'help'`, `WinEnter` +
  `&previewwindow`).
- Folding (nvim-ufo): `foldmethod=indent foldlevel=99 foldlevelstart=99`
  plus the nightfly fill chars; no ufo-style preview.
- Plus the vim defaults nvim gives for free: `nocompatible`, `filetype
  plugin indent on`, `syntax on`, `incsearch hlsearch`, `laststatus=2`,
  `wildmenu`, `ttimeout ttimeoutlen=50`, `encoding=utf-8`, `hidden`,
  `autoread`, `belloff=all`.

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
| `<space>D`, `<space>wa wr wl` | type definition, workspace folders | lspconfig |
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

| Plugin | Dir | Replaces |
|--------|-----|----------|
| bluz71/vim-nightfly-colors | start | same (vim build), + CursorLine `#202d69` override |
| tpope/vim-fugitive | start | fugitive, neogit, diffview |
| tpope/vim-surround | start | same |
| tpope/vim-commentary | start | Comment.nvim |
| tpope/vim-repeat | start | (needed by surround/commentary repeat) |
| vim-scripts/ReplaceWithRegister | start | same |
| christoomey/vim-tmux-navigator | start | same |
| mbbill/undotree | start | undotree, telescope-undo |
| szw/vim-maximizer | start | same |
| preservim/nerdtree | start | nvim-tree |
| airblade/vim-gitgutter | start | gitsigns |
| itchyny/lightline.vim | start | lualine (colours from lualine.lua) |
| mengelbrecht/lightline-bufferline | start | bufferline |
| jiangmiao/auto-pairs | start | nvim-autopairs |
| Yggdroot/indentLine | start | indent-blankline |
| ctrlpvim/ctrlp.vim | start | telescope fallback |
| liuchengxu/vista.vim | start | outline.nvim |
| junegunn/fzf (vim plugin part only) + junegunn/fzf.vim | opt | telescope |
| prabirshrestha/vim-lsp | opt | lspconfig |
| prabirshrestha/asyncomplete.vim + asyncomplete-lsp.vim + asyncomplete-buffer.vim + asyncomplete-file.vim | opt | nvim-cmp sources |
| dense-analysis/ale | opt | nvim-lint, conform |

Each pinned to a release tag (or a commit when the project has no tags) in
`plugins.list`. Licences (MIT / Vim / Apache) are kept in each plugin dir.

### Own harpoon replacement

`plugin/harpoon.vim` + `autoload/harpoon.vim`, ~60 lines: a per-project list
(project = git root, else cwd) stored in `~/.vim/.state/harpoon/<hash>`.
`<leader>aa` adds the current file, `<M-e>` opens the list in a small split
buffer you edit like text (reorder/delete lines, `:w` or `q` saves),
`<M-h/j/k/l>` open entries 1-4, `<M-p>/<M-n>` previous/next.

### Not ported

treesitter (vim syntax files instead), nvim-ufo, render-markdown,
CopilotChat, copilot.vim (needs Node and a GitHub login per server),
neogit/diffview (fugitive covers it), which-key, cheatsheet, lsp_signature
(`gK` covers it), nvim-web-devicons (no Nerd Font guaranteed on the
client path), Mason (nothing is installed on servers), the telescope-specific
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
| C: old vim | RHEL-like template if one exists, else vim 8.0 built into `/opt` on case B's VM | tier 1 without LSP, no errors |
| D: tiny | `vim-tiny` only (`apt purge vim`, or `vim.tiny` binary) | starts with no errors |
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

## Out of scope (for now)

- Hooking my-vim into my-zsh's `install.sh`.
- Installing language servers or tools on servers.
- GUI vim (gvim/MacVim) specifics.
- Keeping my-vim in sync with future my-nvim changes automatically
  (done by hand per change).
