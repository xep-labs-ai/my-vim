" Line blame (git-blame.nvim): after the cursor rests, the cursor line's
" commit as virtual text after the line (vim 9.0.1000+ with +textprop),
" echoed otherwise. On by default; <leader>fgSt toggles. With +job, git runs
" in the background, so a slow blame never blocks typing.
let s:on = 1
let s:vt = has('textprop') && has('patch-9.0.1000')
if s:vt
  silent! call prop_type_add('myvim_blame', {'highlight': 'Comment'})
endif
let s:async = has('job') && has('channel') && has('lambda')
let s:job = ''
let s:shown = ''
" directory -> 1 when it is inside a git work tree (asked once per directory)
let s:in_git = {}

" the file to blame, or '' when there is nothing to blame
function! s:file() abort
  let file = expand('%:p')
  if !s:on || &buftype !=# '' || empty(file) || !filereadable(file) || !executable('git')
    return ''
  endif
  let dir = fnamemodify(file, ':h')
  if !has_key(s:in_git, dir)
    let s:in_git[dir] = system('cd ' . shellescape(dir) . ' && git rev-parse --is-inside-work-tree 2>/dev/null') =~# '^true'
  endif
  return s:in_git[dir] ? file : ''
endfunction

" cd, not git -C (git 1.8); the buffer goes on stdin as text with its final
" newline, or git sees the last line as changed
function! s:cmd(file, line) abort
  return 'cd ' . shellescape(fnamemodify(a:file, ':h')) . ' && git blame --porcelain --contents - -L '
        \ . a:line . ',+1 -- ' . shellescape(a:file)
endfunction

function! s:input() abort
  return join(getline(1, '$'), "\n") . "\n"
endfunction

function! s:parse(out) abort
  if empty(a:out)
    return ''
  endif
  let sha = split(a:out[0])[0]
  if sha =~# '^0\+$'
    return ' Not Committed Yet'
  endif
  let info = {}
  for l in a:out[1:]
    let m = matchlist(l, '^\(\S\+\) \(.*\)$')
    if !empty(m)
      let info[m[1]] = m[2]
    endif
  endfor
  return printf(' %s • %s • %s • <%s>', get(info, 'summary', ''),
        \ strftime('%m-%d-%Y %H:%M:%S', str2nr(get(info, 'author-time', '0'))),
        \ get(info, 'author', ''), sha[:7])
endfunction

" the blame text for the cursor line, '' outside git (synchronous)
function! myvim#blame#text() abort
  let file = s:file()
  if empty(file)
    return ''
  endif
  let out = systemlist(s:cmd(file, line('.')), s:input())
  return v:shell_error ? '' : s:parse(out)
endfunction

" what is shown now ('' when nothing is)
function! myvim#blame#shown() abort
  return s:shown
endfunction

function! s:show(text) abort
  let s:shown = a:text
  if empty(a:text)
    return
  endif
  if s:vt
    call prop_add(line('.'), 0, {'type': 'myvim_blame', 'text': a:text, 'text_align': 'after', 'text_padding_left': 1})
  else
    echo strpart(a:text, 0, &columns - 12)
  endif
endfunction

function! myvim#blame#clear() abort
  if s:async && type(s:job) == v:t_job && job_status(s:job) ==# 'run'
    call job_stop(s:job)
  endif
  let s:shown = ''
  if s:vt
    silent! call prop_remove({'type': 'myvim_blame', 'all': 1})
  endif
endfunction

function! myvim#blame#update() abort
  call myvim#blame#clear()
  let file = s:file()
  if empty(file)
    return
  endif
  if !s:async
    call s:show(myvim#blame#text())
    return
  endif
  " shown only if the cursor is still where it was when git started
  let want = [bufnr('%'), line('.'), b:changedtick]
  let out = []
  let s:job = job_start(['sh', '-c', s:cmd(file, line('.'))], {
        \ 'in_io': 'pipe', 'out_mode': 'nl', 'err_io': 'null',
        \ 'out_cb': {ch, line -> add(out, line)},
        \ 'close_cb': {ch -> [bufnr('%'), line('.'), b:changedtick] == want ? s:show(s:parse(out)) : 0},
        \ })
  let ch = job_getchannel(s:job)
  call ch_sendraw(ch, s:input())
  call ch_close_in(ch)
endfunction

function! myvim#blame#toggle() abort
  let s:on = !s:on
  if s:on
    call myvim#blame#update()
  else
    call myvim#blame#clear()
  endif
  echo 'Line blame ' . (s:on ? 'on' : 'off')
endfunction
