" my-nvim core/scripts.lua: number toggle, preview scrolling, highlight
" inspection, the swap-file prompt, and uc (undotree.lua) to clear undo.
if !exists('g:myvim_tier') | finish | endif

nnoremap <silent> <F5> :call myvim#scripts#toggle_number()<CR>
nnoremap <silent> <C-P><C-D> :call myvim#window#preview_scroll('down')<CR>
nnoremap <silent> <C-P><C-U> :call myvim#window#preview_scroll('up')<CR>
nnoremap <silent> <leader>hi :call myvim#window#inspect()<CR>
nnoremap <silent> uc :call myvim#scripts#clear_undo()<CR>

augroup myvim_swap
  autocmd!
  autocmd SwapExists * call myvim#swap#remember(expand('<afile>:p'), v:swapname)
augroup END
