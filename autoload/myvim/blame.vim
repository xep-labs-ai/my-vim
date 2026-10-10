" Line blame (git-blame.nvim): after the cursor rests, the cursor line's
" commit as virtual text after the line (vim 9.0.1000+ with +textprop),
" echoed otherwise. On by default; <leader>fgSt toggles.
let s:on = 1
let s:vt = has('textprop') && has('patch-9.0.1000')
if s:vt
  silent! call prop_type_add('myvim_blame', {'highlight': 'Comment'})
endif

function! myvim#blame#text() abort
  let file = expand('%:p')
  if !s:on || &buftype !=# '' || empty(file) || !filereadable(file) || !executable('git')
    return ''
  endif
  " cd, not git -C (git 1.8); the buffer as text with its final newline, or
  " git sees the last line as changed
  let cmd = 'cd ' . shellescape(fnamemodify(file, ':h')) . ' && git blame --porcelain --contents - -L '
        \ . line('.') . ',+1 -- ' . shellescape(file)
  let out = systemlist(cmd, join(getline(1, '$'), "\n") . "\n")
  if v:shell_error || empty(out)
    return ''
  endif
  let sha = split(out[0])[0]
  if sha =~# '^0\+$'
    return ' Not Committed Yet'
  endif
  let info = {}
  for l in out[1:]
    let m = matchlist(l, '^\(\S\+\) \(.*\)$')
    if !empty(m)
      let info[m[1]] = m[2]
    endif
  endfor
  return printf(' %s • %s • %s • <%s>', get(info, 'summary', ''),
        \ strftime('%m-%d-%Y %H:%M:%S', str2nr(get(info, 'author-time', '0'))),
        \ get(info, 'author', ''), sha[:7])
endfunction

function! myvim#blame#clear() abort
  if s:vt
    silent! call prop_remove({'type': 'myvim_blame', 'all': 1})
  endif
endfunction

function! myvim#blame#update() abort
  call myvim#blame#clear()
  let text = myvim#blame#text()
  if empty(text)
    return
  endif
  if s:vt
    call prop_add(line('.'), 0, {'type': 'myvim_blame', 'text': text, 'text_align': 'after', 'text_padding_left': 1})
  else
    echo strpart(text, 0, &columns - 12)
  endif
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
