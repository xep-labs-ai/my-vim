" git calls blame made (gitgutter and fugitive call git too)
function! ProbeBlameCalls(file) abort
  return len(filter(readfile(a:file), 'v:val =~# "^\\(rev-parse --is-inside-work-tree\\|blame \\)"'))
endfunction
" starts myvim#blame#update() and returns the time it started (for reltime())
function! ProbeTimed() abort
  let t = reltime()
  call myvim#blame#update()
  return t
endfunction
" git-blame.nvim: ' <summary> • <date> • <author> • <<sha>>' for the cursor line
call ExpectMap('eval', 'n', '<Space>fgSt')
" wipe the buffer first: the Onew scenario leaves it changed, and a changed
" buffer whose file changes on disk stops at vim's W12 prompt
let s:repo = "silent! bwipeout! /tmp/myvim-bl/f.txt | call system('sh ' . shellescape(g:myvim_root . '/tests/samples/make-git-repo.sh') . ' /tmp/myvim-bl') | edit /tmp/myvim-bl/f.txt"
call Scenario('git', 'blame text for a committed line', [], s:repo, '', "myvim#blame#text() =~# '^ add-f • \\d\\d-\\d\\d-\\d\\d\\d\\d \\d\\d:\\d\\d:\\d\\d • Probe • <\\x\\{8}>$'", 1)
call Scenario('git', 'unsaved lines say Not Committed Yet', [], s:repo, 'Onew', 'myvim#blame#text()', ' Not Committed Yet')
call Scenario('eval', 'no blame outside git', ['x'], 'file /tmp/not-in-git.txt', '', 'myvim#blame#text()', '')
call Scenario('git', 'toggle turns it off', [], s:repo, "\<Space>fgSt", 'myvim#blame#text()', '')
" (the state is global: the scenario above left it off, this one turns it on again)
call Scenario('git', 'toggle again turns it back on', [], s:repo, "\<Space>fgSt", "myvim#blame#text() =~# 'add-f'", 1)
" final review: no git per cursor rest outside a work tree, and blame that
" doesn't block vim. A git wrapper on PATH counts calls and slows blame down.
if executable('git')
  let s:fake = '/tmp/myvim-fakegit'
  if !isdirectory(s:fake) | call mkdir(s:fake, 'p') | endif
  if !isdirectory('/tmp/myvim-nogit') | call mkdir('/tmp/myvim-nogit', 'p') | endif
  call writefile(['n'], '/tmp/myvim-nogit/n.txt')
  call writefile(['#!/bin/sh', 'echo "$*" >> ' . s:fake . '/calls',
        \ 'case "$*" in *blame*) sleep "${FAKEGIT_SLEEP:-0}" ;; esac', 'exec ' . exepath('git') . ' "$@"'], s:fake . '/git')
  call system('chmod +x ' . s:fake . '/git')
  let s:path = $PATH
  let $PATH = s:fake . ':' . $PATH
  call Scenario('git', 'outside git, git runs once per directory', [], "call delete('" . s:fake . "/calls') | edit /tmp/myvim-nogit/n.txt", '',
        \ "[myvim#blame#text(), myvim#blame#text(), ProbeBlameCalls('" . s:fake . "/calls')]", ['', '', 1])
  let $FAKEGIT_SLEEP = '1'
  call Scenario('2', 'blame does not block while git runs', [], s:repo,
        \ '', "[reltimefloat(reltime(ProbeTimed())) < 0.5, WaitFor('myvim#blame#shown() =~# \"add-f\"', 5000)]", [1, 1])
  let $FAKEGIT_SLEEP = ''
  let $PATH = s:path
  unlet s:fake s:path
endif
unlet s:repo
