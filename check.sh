#!/bin/sh
# Reports which vim this is, the my-vim tier it gets, the clipboard mode, and
# which optional tools are missing. In a folder from install_tiny.sh or
# install_small.sh (it has a BUNDLE file), also which of its plugins this vim
# skips. Read-only. Exits with the number of problems: a missing vim, a
# broken config, a ~/.vimrc or ~/.vim that keeps vim from reading this one, or
# a bundle plugin missing from the folder.
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
if [ -f "$REPO_DIR/BUNDLE" ]; then
  ok "bundle: $(sed -n 1p "$REPO_DIR/BUNDLE")"
  for p in $(sed -n 2p "$REPO_DIR/BUNDLE"); do
    case " $plugins " in *" $p "*) continue ;; esac
    if [ ! -d "$REPO_DIR/pack/vendor/opt/$p" ]; then
      warn "$p is missing from $REPO_DIR/pack/vendor/opt (incomplete copy?)"
    elif [ "$tier" != 1 ] && [ "$tier" != 2 ]; then
      note "$p not loaded: this vim has no packages"
    else
      case $p in
        vim-tmux-navigator) note "$p not loaded: needs vim 8.0.1108+ (:tnoremap); use tmux keys to change panes" ;;
        vim-nightfly-colors) note "$p not loaded: this vim has no +termguicolors" ;;
        *) warn "$p not loaded" ;;
      esac
    fi
  done
fi
for f in "$HOME/.vimrc" "$HOME/_vimrc"; do
  [ -e "$f" ] && warn "$f exists: vim reads it instead of ~/.vim/vimrc (install.sh moves it aside)"
done
[ "$(cd "$HOME/.vim" 2>/dev/null && pwd -P)" = "$(cd "$REPO_DIR" && pwd -P)" ] ||
  warn "~/.vim isn't $REPO_DIR, so vim doesn't use this config (run install.sh)"
case $clip in
  tmux|osc52|system) ok "clipboard: $clip" ;;
  *) note "clipboard: $clip" ;;
esac
[ "$yankpost" = 0 ] && note "no TextYankPost (vim < 8.0.1394): yanks don't reach the clipboard and p doesn't read the tmux buffer; <leader>yy* and :MessagesToClipboard copy"
if [ -n "${TMUX:-}" ]; then
  v=$(tmux -V 2>/dev/null)
  ok "$v"
  case $(tmux show -gv set-clipboard 2>/dev/null) in
    off) note "tmux set-clipboard is off: yanks reach the tmux buffer but not your terminal" ;;
  esac
fi
if [ -f "$REPO_DIR/BUNDLE" ]; then
  # the bundle has no fzf.vim, LSP or lint plugins: only git matters
  command -v git >/dev/null 2>&1 && ok "git" || note "git not installed (fugitive, gitgutter and line blame need it)"
  exit $PROBLEMS
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
