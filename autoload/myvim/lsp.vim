" gl / gj (lspconfig.lua): the definition of the symbol under the cursor in
" the rightmost / lowest window, splitting when this is the only window there
function! s:edge_window(where) abort
  let best = win_getid()
  let bestpos = -1
  for w in range(1, winnr('$'))
    if getwinvar(w, '&buftype') !=# ''
      continue
    endif
    let pos = win_screenpos(w)[a:where ==# 'right' ? 1 : 0]
    if pos > bestpos
      let bestpos = pos
      let best = win_getid(w)
    endif
  endfor
  return best
endfunction

function! myvim#lsp#definition_in(where) abort
  let buf = bufnr('%')
  let pos = getcurpos()
  let target = s:edge_window(a:where)
  if target == win_getid()
    execute 'botright' (a:where ==# 'right' ? 'vsplit' : 'split')
  else
    call win_gotoid(target)
    execute 'buffer' buf
  endif
  call setpos('.', pos)
  LspDefinition
endfunction
