" git-blame.nvim: line blame when the cursor rests (updatetime=300)
if !exists('g:myvim_tier') | finish | endif
nnoremap <silent> <leader>fgSt :call myvim#blame#toggle()<CR>
augroup myvim_blame
  autocmd!
  autocmd CursorHold * call myvim#blame#update()
  autocmd CursorMoved,InsertEnter,BufLeave * call myvim#blame#clear()
augroup END
