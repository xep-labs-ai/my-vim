" plugin keymaps and settings (telescope, nvim-tree, gitsigns, lualine, ...)
for s:m in ['<Space>ff', '<Space>fF', '<Space>fs', '<Space>fc', '<Space>fe', '<Space>fb', '<Space>fh',
      \ '<Space>fht', '<Space>fg', '<Space>fgf', '<Space>fgs', '<Space>fgb', '<Space>fgc', '<Space>fu',
      \ '<Space>fgdw', '<Space>fgdfc', '<Space>fgdfa', '<Space>ee', '<Space>ef', '<Space>ec',
      \ '<Space>er', '<Space>ea', '<Space>ut', '<Space>up', '<Space>sm', '<Space>mo', '<Space>mf',
      \ 'gcc', 'ys', 'grr']
  call ExpectMap('1', 'n', s:m)
endfor
" vim-tmux-navigator (loads only where :tnoremap exists, see vimrc)
if index(get(g:, 'myvim_plugins', []), 'vim-tmux-navigator') >= 0
  for s:m in ['<C-h>', '<C-j>', '<C-k>', '<C-l>']
    call ExpectMap('1', 'n', s:m)
  endfor
endif
call ExpectMap('term', 'n', '<Space>ttt')
call ExpectMap('term', 'n', '<Space>ttv')
call ExpectMap('term', 't', '<C-h>')
call ExpectMap('1', 'i', '<CR>')
unlet s:m
call Expect('1', "get(g:, 'colors_name', '')", exists('+termguicolors') ? 'nightfly' : '')
call Expect('1', '&showtabline', 2)
call Expect('1', '&showmode', 0)
call Expect('1', "get(get(g:, 'lightline', {}), 'colorscheme', '')", 'myvim')
call Expect('1', "exists('+termguicolors') && &termguicolors ? synIDattr(hlID('CursorLine'), 'bg#') : '#202d69'", '#202d69')
call Expect('1', "get(g:, 'gitgutter_map_keys', 1)", 0)
call Expect('1', "get(g:, 'AutoPairsShortcutToggle', '<M-p>')", '')
call Expect('fzf', "$FZF_DEFAULT_OPTS =~# 'ctrl-j:down'", 1)
" the quote at line 1 col 2 (conceallevel is per window: indentLine may leave 2)
call Scenario('1', 'json quotes stay visible', [], "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/sample.json')", '', 'synconcealed(1, 2)[0]', 0)
call Scenario('1', '<leader>ee opens NERDTree', [], 'cd ' . fnameescape(g:myvim_root), "\<Space>ee", "len(filter(range(1, winnr('$')), 'getbufvar(winbufnr(v:val), \"&filetype\") ==# \"nerdtree\"'))", 1)
call Scenario('1', '<leader>ea then <leader>ec without errors', [], 'cd ' . fnameescape(g:myvim_root . '/tests'), "\<Space>ee\<C-w>p\<Space>ea\<Space>ec", 'v:errmsg', '')
call Scenario('1', 'gcc comments a line', ['x = 1'], 'setfiletype python', 'gcc', 'getline(1)', '# x = 1')
call Scenario('1', 'griw replaces a word with the register', ['old word'], 'let @" = "new"', 'griw', 'getline(1)', 'new word')
call Scenario('1', 'ysiw" surrounds', ['word'], '', 'ysiw"', 'getline(1)', '"word"')
call Scenario('1', '<CR> after ( opens a pair on new lines', [''], '', "if(\<CR>\<Esc>", 'line("$")', 3)
silent! NERDTreeClose
