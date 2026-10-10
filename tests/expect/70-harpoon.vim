" harpoon.lua: per-cwd list of files
for s:m in ['<Space>aa', '<M-e>', '<M-h>', '<M-j>', '<M-k>', '<M-l>', '<M-p>', '<M-n>']
  call ExpectMap('eval', 'n', s:m)
endfor
unlet s:m
let s:setup = "if !isdirectory('/tmp/myvim-hp') | call mkdir('/tmp/myvim-hp', 'p') | endif | cd /tmp/myvim-hp | call writefile(['a'], 'a.txt') | call writefile(['b'], 'b.txt')"
      \ . " | call delete(g:myvim_state . '/harpoon/' . substitute(getcwd(), '/', '%', 'g'))"
      \ . " | edit a.txt | call myvim#harpoon#add() | edit b.txt | call myvim#harpoon#add()"
call Scenario('eval', 'add keeps the order', [], s:setup, '', 'myvim#harpoon#list()', ['a.txt', 'b.txt'])
call Scenario('eval', '<M-h> opens entry 1', [], s:setup, "\<M-h>", "expand('%:t')", 'a.txt')
call Scenario('eval', '<M-j> opens entry 2', [], s:setup, "\<M-h>\<M-j>", "expand('%:t')", 'b.txt')
call Scenario('eval', '<M-p> from entry 2 goes to 1', [], s:setup, "\<M-p>", "expand('%:t')", 'a.txt')
call Scenario('eval', '<M-k> with no entry 3 stays and is quiet', [], s:setup, "\<M-k>", "[expand('%:t'), v:errmsg]", ['b.txt', ''])
call Scenario('eval', '<M-e> menu lists the files', [], s:setup, "\<M-e>", "[&buftype, getline(1, '$')]", ['acwrite', ['a.txt', 'b.txt']])
call Scenario('eval', 'deleting a line in the menu and :w saves it', [], s:setup, "\<M-e>dd:w\<CR>", 'myvim#harpoon#list()', ['b.txt'])
unlet s:setup
