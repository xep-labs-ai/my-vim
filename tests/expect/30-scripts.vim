" core/scripts.lua
call ExpectMap('eval', 'n', '<F5>')
call ExpectMap('eval', 'n', '<C-P><C-D>')
call ExpectMap('eval', 'n', '<C-P><C-U>')
call ExpectMap('eval', 'n', '<Space>hi')
call ExpectMap('eval', 'n', 'uc')
call Expect('eval', "exists('#myvim_swap#SwapExists')", 1)
call Scenario('eval', 'F5 turns numbers off', ['a'], 'setlocal number relativenumber', "\<F5>", '[&l:number, &l:relativenumber]', [0, 0])
call Scenario('eval', 'F5 twice turns them back on', ['a'], 'setlocal number relativenumber', "\<F5>\<F5>", '[&l:number, &l:relativenumber]', [1, 1])
" seq_last keeps counting after a clear; the entries are what's gone
call Scenario('eval', 'uc clears the undo history', ['a'], '', "xuc", 'len(undotree().entries)', 0)
call Scenario('eval', 'preview scroll without a preview window is quiet', ['a'], '', "\<C-P>\<C-D>", 'v:errmsg', '')
