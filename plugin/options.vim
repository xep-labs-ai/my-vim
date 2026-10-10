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
" bin: 7.4.1027
let &nrformats = has('patch-7.4.1027') ? 'bin,hex' : 'hex'
set nostartofline
set smarttab
set formatoptions=tcqj
set nojoinspaces
set wildmenu
if exists('+belloff')
  set belloff=all
endif
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
  if exists('&t_SR')
    let &t_SR = "\e[4 q"
  endif
  let &t_EI = "\e[2 q"
  if $TERM =~# '^\%(screen\|tmux\)'
    if exists('+termguicolors')
      let &t_8f = "\e[38;2;%lu;%lu;%lum"
      let &t_8b = "\e[48;2;%lu;%lu;%lum"
    endif
    " bracketed paste: a terminal paste into insert mode doesn't auto-indent each line
    if exists('&t_BE')
      let &t_BE = "\e[?2004h"
      let &t_BD = "\e[?2004l"
      exec "set t_PS=\e[200~"
      exec "set t_PE=\e[201~"
    endif
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
