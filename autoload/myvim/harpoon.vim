" A small harpoon (harpoon.lua): a list of files per working directory,
" kept in <state>/harpoon/<cwd with / as %>.

function! s:path() abort
  return g:myvim_state . '/harpoon/' . substitute(getcwd(), '/', '%', 'g')
endfunction

function! myvim#harpoon#list() abort
  if empty(g:myvim_state) || !filereadable(s:path())
    return []
  endif
  return filter(readfile(s:path()), 'v:val !~# "^\\s*$"')
endfunction

function! s:save(list) abort
  if empty(g:myvim_state)
    echo 'harpoon: no state dir'
    return
  endif
  call writefile(a:list, s:path())
endfunction

function! myvim#harpoon#add() abort
  if empty(expand('%'))
    echo 'harpoon: buffer has no file'
    return
  endif
  let rel = fnamemodify(expand('%:p'), ':.')
  let list = myvim#harpoon#list()
  if index(list, rel) < 0
    call add(list, rel)
    call s:save(list)
  endif
  echo 'harpoon: ' . rel . ' (' . (index(list, rel) + 1) . ')'
endfunction

function! myvim#harpoon#select(n) abort
  let list = myvim#harpoon#list()
  if a:n < 1 || a:n > len(list)
    echo 'harpoon: no file ' . a:n
    return
  endif
  execute 'edit' fnameescape(list[a:n - 1])
endfunction

" <M-p>/<M-n>: previous/next entry, no wrap (harpoon's default)
function! myvim#harpoon#cycle(step) abort
  let list = myvim#harpoon#list()
  if empty(list)
    return
  endif
  let i = index(list, fnamemodify(expand('%:p'), ':.'))
  let n = i < 0 ? 1 : min([max([i + 1 + a:step, 1]), len(list)])
  call myvim#harpoon#select(n)
endfunction

" <M-e>: the list in a buffer; edit lines, :w or q saves, <CR> opens
function! myvim#harpoon#menu() abort
  let list = myvim#harpoon#list()
  execute 'botright' min([max([len(list), 1]), 10]) . 'new'
  setlocal buftype=acwrite bufhidden=wipe noswapfile nobuflisted
  execute 'file' fnameescape('harpoon://' . getcwd())
  call setline(1, list)
  setlocal nomodified
  augroup myvim_harpoon_menu
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call s:menu_save()
  augroup END
  nnoremap <buffer> <silent> q :call <SID>menu_close()<CR>
  nnoremap <buffer> <silent> <M-e> :call <SID>menu_close()<CR>
  nnoremap <buffer> <silent> <CR> :call <SID>menu_open()<CR>
endfunction

function! s:menu_save() abort
  call s:save(filter(getline(1, '$'), 'v:val !~# "^\\s*$"'))
  setlocal nomodified
endfunction

function! s:menu_close() abort
  call s:menu_save()
  close
endfunction

function! s:menu_open() abort
  let file = getline('.')
  call s:menu_close()
  if !empty(file)
    execute 'edit' fnameescape(file)
  endif
endfunction
