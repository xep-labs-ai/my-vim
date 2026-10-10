" Vendored plugins load (by tier); their settings and keys are checked in 61-plugin-config.vim
for s:p in ['vim-nightfly-colors', 'vim-fugitive', 'vim-surround', 'vim-commentary', 'vim-repeat',
      \ 'ReplaceWithRegister', 'undotree', 'vim-maximizer', 'nerdtree',
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
" vim-tmux-navigator runs :tnoremap inside tmux (vim 8.0.1108+ with +terminal)
call Expect('1', "index(g:myvim_plugins, 'vim-tmux-navigator') >= 0", exists(':tnoremap') == 2 ? 1 : 0)
call Expect('1', "exists(':TmuxNavigateLeft')", exists(':tnoremap') == 2 ? 2 : 0)
call Expect('fzf', "exists(':Files')", 2)
call Expect('2', "exists(':LspDefinition')", 2)
call Expect('2', "exists(':ALELint')", 2)
call Expect('1', "!empty(globpath(&runtimepath, 'doc/tags'))", 1)
unlet s:p
