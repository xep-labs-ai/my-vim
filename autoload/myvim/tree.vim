" NERDTree helpers for <leader>ef ec er ea (nvim-tree.lua)
function! s:is_open() abort
  return exists('g:NERDTree') && g:NERDTree.IsOpen()
endfunction

function! myvim#tree#find_toggle() abort
  if s:is_open()
    NERDTreeClose
  elseif empty(expand('%'))
    NERDTree
  else
    NERDTreeFind
  endif
endfunction

" run FN inside the tree window, then come back
function! s:in_tree(fn) abort
  if s:is_open()
    NERDTreeFocus
  else
    NERDTree
  endif
  call call(a:fn, [])
  wincmd p
endfunction

function! s:collapse() abort
  call b:NERDTree.root.closeChildren()
  call b:NERDTree.render()
endfunction

function! s:refresh() abort
  call b:NERDTree.root.refresh()
  call b:NERDTree.render()
endfunction

function! s:expand() abort
  call b:NERDTree.root.openRecursively()
  call b:NERDTree.render()
endfunction

function! myvim#tree#collapse() abort
  call s:in_tree(function('s:collapse'))
endfunction

function! myvim#tree#refresh() abort
  call s:in_tree(function('s:refresh'))
endfunction

function! myvim#tree#expand_all() abort
  call s:in_tree(function('s:expand'))
endfunction
