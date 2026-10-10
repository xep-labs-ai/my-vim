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
unlet s:repo
