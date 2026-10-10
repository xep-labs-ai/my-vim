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
      " vim 7.4's mkdir(..., 'p') fails (E739) on a directory that exists
      for sub in ['undo', 'swap', 'backup', 'harpoon']
        if !isdirectory(dir . '/' . sub)
          silent! call mkdir(dir . '/' . sub, 'p', 0700)
        endif
      endfor
      if filewritable(dir . '/undo') == 2
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
