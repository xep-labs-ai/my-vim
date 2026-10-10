" <CR> in insert mode (nvim-cmp): accept a selected completion, otherwise a
" newline (closing an unselected popup), with auto-pairs' return handling
function! myvim#complete#cr() abort
  let pairs = exists('*AutoPairsReturn') ? "\<C-r>=AutoPairsReturn()\<CR>" : ''
  if pumvisible()
    if !exists('*complete_info') || complete_info(['selected']).selected >= 0
      return "\<C-y>"
    endif
    return "\<C-e>\<CR>" . pairs
  endif
  return "\<CR>" . pairs
endfunction
