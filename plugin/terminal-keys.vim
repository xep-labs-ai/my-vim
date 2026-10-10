" Alt keys in terminal vim arrive as Esc + key: tell vim they are <M-key>
" (resize <M-,>/<M-.>, harpoon <M-h/j/k/l/e/p/n>). ttimeoutlen=50 (options.vim)
" keeps a real Esc from waiting and leaves `jk` alone.
if !exists('g:myvim_tier') || has('gui_running') | finish | endif
for s:k in ['h', 'j', 'k', 'l', 'e', 'p', 'n', ',', '.']
  execute 'set <M-' . s:k . ">=\e" . s:k
endfor
unlet s:k
