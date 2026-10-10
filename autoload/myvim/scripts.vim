" F5: line numbers on/off
function! myvim#scripts#toggle_number() abort
  if &relativenumber
    setlocal norelativenumber nonumber
    echo 'Numbering off'
  else
    setlocal relativenumber number
    echo 'Numbering on'
  endif
endfunction

" uc: forget the undo history of the current buffer
function! myvim#scripts#clear_undo() abort
  let old = &undolevels
  setlocal undolevels=-1
  execute "normal! a \<BS>\<Esc>"
  let &l:undolevels = old
  echo 'Undo history cleared'
endfunction
