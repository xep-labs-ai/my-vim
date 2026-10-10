" harpoon.lua keys (Alt keys: plugin/terminal-keys.vim)
if !exists('g:myvim_tier') | finish | endif
nnoremap <silent> <leader>aa :call myvim#harpoon#add()<CR>
nnoremap <silent> <M-e> :call myvim#harpoon#menu()<CR>
nnoremap <silent> <M-h> :call myvim#harpoon#select(1)<CR>
nnoremap <silent> <M-j> :call myvim#harpoon#select(2)<CR>
nnoremap <silent> <M-k> :call myvim#harpoon#select(3)<CR>
nnoremap <silent> <M-l> :call myvim#harpoon#select(4)<CR>
nnoremap <silent> <M-p> :call myvim#harpoon#cycle(-1)<CR>
nnoremap <silent> <M-n> :call myvim#harpoon#cycle(1)<CR>
