" my-nvim core/keymaps.lua and vimscript/keymaps.vim. Plugin keymaps are in
" plugin/plugins.vim, LSP ones in plugin/lsp.vim.
if !exists('g:myvim_tier') | finish | endif

inoremap jk <Esc>
nnoremap <leader>hn :nohl<CR>
nnoremap Y y$

" x deletes without copying; dd keeps the line in register 9 only
nnoremap x "_x
" Before 8.2, v:register stays "9" for the next command, so a p right after dd
" asked for register 9 (E353): "" resets it, <Esc> drops it again
if v:version < 802
  nnoremap dd "9dd""<Esc>
else
  nnoremap dd "9dd
endif

nnoremap <leader>+ <C-a>
nnoremap <leader>- <C-x>

" splits
nnoremap <leader>sv <C-w>v
nnoremap <leader>sh <C-w>s
nnoremap <leader>se <C-w>=
nnoremap <leader>sx :close<CR>

" tabs
nnoremap <leader>to :tabnew<CR>
nnoremap <leader>tx :tabclose<CR>
nnoremap <leader>tn :tabn<CR>
nnoremap <leader>tp :tabp<CR>
for s:n in range(1, 9)
  execute 'noremap <leader>' . s:n . ' ' . s:n . 'gt'
endfor
unlet s:n

" preview window: open the tag under the cursor in a vertical split
nnoremap <silent> <C-W>{{ :call myvim#window#pedit_vertical()<CR>

" replace the selection (register h), with confirmation from the cursor on / without, whole file
xnoremap <C-r> "hy:.,$s/\C<C-r>h//gc<left><left><left>
xnoremap <C-e> "hy:%s/\C<C-r>h//g<left><left>

" blank lines without leaving normal mode
nnoremap <leader>o o<Esc>
nnoremap <leader>O O<Esc>

" highlight the word under the cursor without jumping
nnoremap <silent> <leader>hh :let @/='\<<C-R>=expand("<cword>")<CR>\>'<CR>:set hls<CR>
" highlight the visual selection (yanks into register h, not the clipboard)
xnoremap <silent> <CR> "hy:silent! let searchTerm = '\V'.substitute(escape(@h, '\/'), "\n", '\\n', "g") <bar> let @/ = searchTerm <bar> echo '/'.@/ <bar> call histadd("search", searchTerm) <bar> set hls<CR>
" Ctrl-C toggles hlsearch
nnoremap <silent> <C-c> :if (&hlsearch == 1) \| set nohlsearch \| else \| set hlsearch \| endif<CR>

" file path to the clipboard: relative, full, name
nnoremap <silent> <leader>yyr :call myvim#clip#copy(expand('%'))<CR>
nnoremap <silent> <leader>yyp :call myvim#clip#copy(expand('%:p'))<CR>
nnoremap <silent> <leader>yyf :call myvim#clip#copy(expand('%:t'))<CR>

" resize (not <M-h>: harpoon uses <M-h/j/k/l>)
nnoremap <M-,> :vertical resize -2<CR>
nnoremap <M-.> :vertical resize +2<CR>
