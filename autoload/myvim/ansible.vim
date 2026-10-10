" gf on a role name (roles:, role:, include_role, tasks_from) opens the
" role's tasks file; anywhere else it opens the file under the cursor.

" roles/<role>/tasks/<file> in the file's directory or any directory above
" (a playbook next to roles/ or in playbooks/, a role calling a role)
function! s:find_role_tasks(role, file) abort
  let dir = expand('%:p:h')
  while 1
    let cands = [dir . '/roles/' . a:role . '/tasks/' . a:file]
    if fnamemodify(dir, ':t') ==# 'roles'
      call add(cands, dir . '/' . a:role . '/tasks/' . a:file)
    endif
    for p in cands
      if filereadable(p)
        return p
      endif
    endfor
    let parent = fnamemodify(dir, ':h')
    if parent ==# dir
      return ''
    endif
    let dir = parent
  endwhile
endfunction

function! myvim#ansible#gf() abort
  let word = expand('<cword>')
  let cfile = expand('<cfile>')
  let row = line('.')
  let w = '\V' . escape(word, '\')
  let role_style = 0
  let include_role = 0
  let tasks_from = ''
  for l in getline(max([row - 2, 1]), row + 2)
    if l =~# 'role\s*:\s*' . w || l =~# 'roles\s*:' || l =~# '^\s*-\s*' . w
      let role_style = 1
    endif
    if l =~# 'include_role'
      let include_role = 1
    endif
    let m = matchlist(l, 'tasks_from\s*:\s*\(.\+\)')
    if !empty(m)
      let tasks_from = substitute(m[1], '^\s*\|\s*$', '', 'g')
      if tasks_from !~# '\.ya\?ml$'
        let tasks_from .= '.yml'
      endif
    endif
  endfor

  if role_style || include_role
    let target = empty(tasks_from) ? 'main.yml' : tasks_from
    let path = s:find_role_tasks(word, target)
    if !empty(path)
      execute 'edit' fnameescape(path)
      return
    endif
    " one line: a longer message stops at "Press ENTER" before the finder opens
    echohl Comment | echo printf('Role %s (tasks/%s) not found: searching files', word, target) | echohl None
    if exists('g:myvim_plugins') && (index(g:myvim_plugins, 'fzf.vim') >= 0 || index(g:myvim_plugins, 'ctrlp.vim') >= 0)
      call myvim#find#files(0, word)
    endif
    return
  endif

  let abs = expand('%:p:h') . '/' . cfile
  if filereadable(abs)
    execute 'edit' fnameescape(abs)
    return
  endif
  try
    normal! gf
  catch
    echohl Comment | echo 'File not found: ' . cfile | echohl None
  endtry
endfunction
