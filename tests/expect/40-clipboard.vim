" Clipboard in tmux mode (run-probe's private tmux). The client side (OSC 52
" reaching the terminal) is tests/cliptest, run from the client VM.
call Expect('eval', "get(g:, 'myvim_clip_mode', '')", 'tmux')
call Expect('eval', "exists(':MessagesToClipboard')", 2)
" the tmux p maps exist only with TextYankPost (else yanks never reach the buffer)
call ExpectMap('yankpost', 'n', 'p')
call ExpectMap('yankpost', 'x', 'p')
call ExpectMap('yankpost', 'n', 'P')
" yanks reach tmux from a 0 ms timer: give it time to fire, as typing does
function! ProbeTmuxBuffer() abort
  sleep 50m
  return system('tmux save-buffer -')
endfunction
let s:buf = 'ProbeTmuxBuffer()'
" %s: a plain word (no quotes or spaces)
let s:set = "call system('tmux set-buffer -- %s')"
call Scenario('yankpost', 'yy reaches the tmux buffer', ['clip-yank-1'], '', 'yy', s:buf, "clip-yank-1\n")
call Scenario('yankpost', 'yiw reaches the tmux buffer', ['word other'], '', 'yiw', s:buf, 'word')
call Scenario('yankpost', 'deletes reach it too (unnamedplus)', ['gone'], '', 'diw', s:buf, 'gone')
call Scenario('yankpost', 'yank into a named register does not', ['named'], printf(s:set, 'keep-1'), '"ayy', s:buf, 'keep-1')
call Scenario('tmux', 'x does not touch the tmux buffer', ['xyz'], printf(s:set, 'keep-2'), 'x', s:buf, 'keep-2')
" vim < 8.2 kept v:register at _ after the "_x mapping: p pasted nothing
call Scenario('yankpost', 'xp pastes the clipboard', ['abc'], printf(s:set, 'q'), 'xp', 'getline(1)', 'bqc')
call Scenario('yankpost', 'p pastes the tmux buffer (another pane set it)', ['a'], printf(s:set, 'from-pane'), 'p', 'getline(1)', 'afrom-pane')
call Scenario('yankpost', '3p pastes three times', ['a'], printf(s:set, 'z'), '3p', 'getline(1)', 'azzz')
call Scenario('tmux', '"ap pastes register a, not the tmux buffer', ['a'], 'let @a = "reg-a" | ' . printf(s:set, 'tmux-text'), '"ap', 'getline(1)', 'areg-a')
call Scenario('yankpost', 'dd then p pastes the clipboard, as with unnamedplus', ['one', 'two'], printf(s:set, 'clip'), 'ddp', 'getline(1, "$")', ['tclipwo'])
call Scenario('yankpost', 'yy, dd, p pastes the yanked line', ['one', 'two'], '', 'yyjddp', 'getline(1, "$")', ['one', 'one'])
call Scenario('yankpost', 'a blockwise yank stays blockwise', ['ab', 'cd'], '', "\<C-v>jyP", 'getline(1, "$")', ['aab', 'ccd'])
call Scenario('yankpost', 'visual p takes the tmux buffer', ['old'], printf(s:set, 'new'), 'viwp', 'getline(1)', 'new')
call Scenario('tmux', '<leader>yyf copies the file name', [], 'file /tmp/probe-name.txt', "\<Space>yyf", s:buf, 'probe-name.txt')
call Scenario('tmux', ':MessagesToClipboard copies :messages', [], 'unsilent echomsg "probe-msg-42"', ":MessagesToClipboard\<CR>", s:buf . " =~# 'probe-msg-42'", 1)
" final review: yanks without TextYankPost never reach the tmux buffer, so p
" must not read it there (yyp pasted an older tmux buffer on vim 7.4)
call Scenario('tmux', 'yyp pastes the yanked line, not an older tmux buffer', ['mine'], printf(s:set, 'other'), 'yyp', 'getline(1, "$")', ['mine', 'mine'])
" . after the tmux p repeats the paste (put() ran :normal! inside a function)
call Scenario('yankpost', 'p then . pastes twice', ['a'], printf(s:set, 'Y'), 'p.', 'getline(1)', 'aYY')
call Scenario('yankpost', '. after p repeats the paste, not an earlier change', ['abc'], printf(s:set, 'Z'), 'rqp.', 'getline(1)', 'qZZbc')
" :g/x/d fires TextYankPost per line: one clipboard update, after the command
function! ProbeTmuxIs(text) abort
  return system('tmux save-buffer -') ==# a:text
endfunction
call Scenario('yankpost', ':g/x/d updates the clipboard once', ['x1', 'x2', 'x3', 'y'], 'let g:probe_nb = len(systemlist("tmux list-buffers"))', ":g/x/d\<CR>",
      \ "[WaitFor('ProbeTmuxIs(\"x3\\n\")', 2000), len(systemlist('tmux list-buffers')) - g:probe_nb]", [1, 1])
unlet s:buf s:set
