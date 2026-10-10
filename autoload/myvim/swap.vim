" After vim's own swap-file dialog: when the recovered buffer is unchanged
" (nothing to recover), offer to delete the swap file (core/scripts.lua).
" Keyed by file name, as in my-nvim: <abuf> is 0 during SwapExists.
let s:pending = {}

function! myvim#swap#remember(file, swap) abort
  let s:pending[a:file] = a:swap
  augroup myvim_swap_ask
    execute 'autocmd! BufReadPost' fnameescape(a:file)
    execute 'autocmd BufReadPost' fnameescape(a:file) 'call myvim#swap#ask(' . string(a:file) . ')'
  augroup END
endfunction

function! myvim#swap#ask(file) abort
  execute 'autocmd! myvim_swap_ask BufReadPost' fnameescape(a:file)
  " after vim's recovery messages
  if has('timers')
    call timer_start(0, function('s:ask', [a:file]))
  else
    call s:ask(a:file)
  endif
endfunction

function! s:ask(file, ...) abort
  let swap = get(s:pending, a:file, '')
  silent! call remove(s:pending, a:file)
  if empty(swap) || !filereadable(swap) || expand('%:p') !=# a:file || &modified
    return
  endif
  if input('Delete swap file? (y/N) ') =~? '^y'
    echo delete(swap) == 0 ? 'Deleted swap: ' . swap : 'Failed to delete swap: ' . swap
  else
    echo 'Kept swap: ' . swap
  endif
endfunction
