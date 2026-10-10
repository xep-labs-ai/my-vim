" keymaps.lua + vimscript/keymaps.vim
for s:m in ['<Space>hn', '<Space>+', '<Space>-', '<Space>sv', '<Space>sh', '<Space>se', '<Space>sx',
      \ '<Space>to', '<Space>tx', '<Space>tn', '<Space>tp', '<C-W>{{', '<Space>o', '<Space>O',
      \ '<Space>hh', '<C-c>', '<Space>yyr', '<Space>yyp', '<Space>yyf', '<M-,>', '<M-.>', 'Y', 'x', 'dd']
  call ExpectMap('eval', 'n', s:m)
endfor
for s:n in range(1, 9)
  call ExpectMap('eval', 'n', '<Space>' . s:n)
endfor
call ExpectMap('eval', 'i', 'jk')
call ExpectMap('eval', 'x', '<C-r>')
call ExpectMap('eval', 'x', '<C-e>')
call ExpectMap('eval', 'x', '<CR>')
unlet s:m s:n
call Scenario('eval', 'x does not touch the unnamed register', ['abc'], 'let @" = "keep"', 'x', '[getline(1), @"]', ['bc', 'keep'])
" "9dd: an explicit register, so not the clipboard; a line delete still
" shifts the numbered registers, so the line ends up in "1 (nvim does the same)
call Scenario('eval', 'dd deletes into a named register', ['one', 'two'], '', 'dd', '[maparg("dd", "n"), @1]', ['"9dd', "one\n"])
call Scenario('eval', 'jk leaves insert mode', ['ab'], '', 'ixjk', '[getline(1), mode()]', ['xab', 'n'])
call Scenario('eval', '<leader>o adds a line below', ['a'], '', "\<Space>o", 'getline(1, "$")', ['a', ''])
call Scenario('eval', '<leader>hh highlights the word, cursor stays', ['foo bar foo'], '', "w\<Space>hh", '[@/, col(".")]', ['\<bar\>', 5])
call Scenario('eval', 'visual <CR> searches the selection via register h', ['a.b a.b'], 'let @h = ""', "v2l\<CR>", '[@/, @h]', ['\Va.b', 'a.b'])
call Scenario('eval', '<leader>+ increments', ['x 41'], '', "\<Space>+", 'getline(1)', 'x 42')
call Scenario('eval', 'Y yanks to the end of line', ['abc def'], '', 'wY', '@"', 'def')
call Scenario('eval', '<leader>2 goes to tab 2', [], 'tabnew | tabnew | tabfirst', "\<Space>2", 'tabpagenr()', 2)
" the tab scenario leaves tabs behind
silent! tabonly
