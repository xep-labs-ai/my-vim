" Test probe. tests/run-probe.sh starts vim with `-c 'source tests/probe.vim'`;
" the checks run once vim has started (after VimEnter, so plugins that start
" on VimEnter, like vim-lsp, are up). Every tests/expect/*.vim is sourced in
" order; each line of the report is PASS/FAIL/SKIP, then FAILS n and DONE.
let s:dir = expand('<sfile>:p:h')
let s:out = []
let s:fails = 0
let s:lsp_up = 0

function! s:ok(cond) abort
  let tier = get(g:, 'myvim_tier', -1)
  if a:cond ==# 'eval'
    return 1
  elseif a:cond =~# '^\d$'
    return tier >= str2nr(a:cond)
  elseif a:cond ==# 'fzf'
    return get(g:, 'myvim_fzf', 0)
  elseif a:cond ==# 'nofzf'
    return tier >= 1 && !get(g:, 'myvim_fzf', 0)
  elseif a:cond ==# 'tmux'
    return get(g:, 'myvim_clip_mode', '') ==# 'tmux'
  elseif a:cond ==# 'yankpost'
    return exists('##TextYankPost')
  elseif a:cond ==# 'lsp'
    return s:lsp_up
  elseif a:cond =~# '^lsp:'
    return s:lsp_up && &filetype ==# a:cond[4:]
  elseif a:cond ==# 'ale'
    return tier >= 2 && executable('yamllint')
  elseif a:cond ==# 'git'
    return executable('git')
  elseif a:cond ==# 'term'
    return has('terminal')
  endif
  throw 'probe: unknown condition ' . a:cond
endfunction

function! s:report(pass, what) abort
  call add(s:out, (a:pass ? 'PASS ' : 'FAIL ') . a:what)
  if !a:pass
    let s:fails += 1
  endif
endfunction

function! s:same(got, want) abort
  return type(a:got) == type(a:want) && a:got ==# a:want
endfunction

function! WaitFor(expr, ms) abort
  let waited = 0
  while waited < a:ms
    if eval(a:expr)
      return 1
    endif
    sleep 100m
    let waited += 100
  endwhile
  return eval(a:expr) ? 1 : 0
endfunction

function! Expect(cond, expr, want) abort
  if !s:ok(a:cond)
    call add(s:out, 'SKIP ' . a:expr)
    return
  endif
  try
    let got = eval(a:expr)
  catch
    let got = 'ERROR ' . v:exception
  endtry
  call s:report(s:same(got, a:want), printf('%s (got %s, want %s)', a:expr, string(got), string(a:want)))
endfunction

function! ExpectMap(cond, mode, lhs) abort
  if !s:ok(a:cond)
    call add(s:out, 'SKIP map ' . a:mode . ' ' . a:lhs)
    return
  endif
  call s:report(!empty(maparg(a:lhs, a:mode)), 'map ' . a:mode . ' ' . a:lhs)
endfunction

function! Scenario(cond, name, lines, setup, keys, expr, want) abort
  if !s:ok(a:cond)
    call add(s:out, 'SKIP ' . a:name)
    return
  endif
  let keep = bufnr('%')
  let cwd = getcwd()
  let v:errmsg = ''
  enew!
  setlocal buftype=nofile bufhidden=wipe noswapfile
  call setline(1, a:lines)
  call cursor(1, 1)
  try
    if !empty(a:setup)
      silent execute a:setup
    endif
    if !empty(a:keys)
      silent execute 'normal' a:keys
    endif
    let got = eval(a:expr)
  catch
    let got = 'ERROR ' . v:exception
  endtry
  call s:report(s:same(got, a:want), printf('%s (got %s, want %s)', a:name, string(got), string(a:want)))
  silent! only!
  silent! execute 'buffer!' keep
  silent! execute 'cd' fnameescape(cwd)
endfunction

function! s:messages() abort
  redir => m
  silent messages
  redir END
  return m
endfunction

function! s:main() abort
  " what startup left behind, before any check adds to it
  call add(s:out, 'errmsg=' . v:errmsg)
  for l in split(s:messages(), "\n")
    call add(s:out, 'MSG ' . l)
  endfor
  call add(s:out, 'tier=' . get(g:, 'myvim_tier', -1) . ' version=' . v:version . ' clip=' . get(g:, 'myvim_clip_mode', ''))
  " an LSP server registered for the first buffer's filetype: wait for it
  for fts in values(get(g:, 'myvim_lsp_servers', {}))
    if index(fts, &filetype) >= 0
      let s:lsp_up = WaitFor("exists('b:myvim_lsp')", 60000)
      call s:report(s:lsp_up, 'LSP attached to ' . expand('%:t'))
      break
    endif
  endfor
  for f in sort(split(glob(s:dir . '/expect/*.vim'), "\n"))
    try
      execute 'source' fnameescape(f)
    catch
      call s:report(0, fnamemodify(f, ':t') . ' threw ' . v:exception . ' at ' . v:throwpoint)
    endtry
  endfor
  call add(s:out, 'FAILS ' . s:fails)
  call add(s:out, 'DONE')
  call writefile(s:out, $PROBE_OUT)
endfunction

if has('vim_starting')
  augroup probe
    autocmd!
    " nested: the checks must trigger autocmds (TextYankPost, BufWinEnter, ...)
    autocmd VimEnter * nested call s:main()
  augroup END
else
  call s:main()
endif
