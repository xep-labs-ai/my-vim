" <leader>ttt / <leader>ttv (toggleterm): show the running terminal in a tab
" or a bottom split, hide the split again, or start one
function! myvim#term#toggle(where) abort
  for w in range(1, winnr('$'))
    if getbufvar(winbufnr(w), '&buftype') ==# 'terminal' && a:where ==# 'split'
      execute w . 'close'
      return
    endif
  endfor
  let running = filter(range(1, bufnr('$')), 'bufexists(v:val) && getbufvar(v:val, "&buftype") ==# "terminal" && term_getstatus(v:val) =~# "running"')
  if a:where ==# 'tab'
    if empty(running) | tab terminal ++close | else | execute 'tab sbuffer' running[0] | endif
  else
    if empty(running) | botright terminal ++close | else | execute 'botright sbuffer' running[0] | endif
  endif
endfunction
