" lspconfig / nvim-cmp / nvim-lint / conform equivalents
call Expect('2', "type(get(g:, 'myvim_lsp_servers', 0))", type({}))
call ExpectMap('2', 'n', '<Space>ll')
call ExpectMap('2', 'n', '<Space>fm')
call ExpectMap('2', 'x', '<Space>fm')
call ExpectMap('2', 'n', '<Space>lspe')
call ExpectMap('2', 'n', '<Space>lsps')
call ExpectMap('2', 'n', '<Space>lspI')
call ExpectMap('2', 'i', '<C-e>')
call Expect('2', '&completeopt', 'menu,menuone,noselect')
" buffer-local keys once a server is attached to the first file
for s:m in ['gd', 'gD', 'gi', 'gr', 'K', 'gK', 'gl', 'gj', '<Space>pd', '<Space>pt', '<Space>pi',
      \ '<Space>pr', '<Space>pD', '<Space>pP', '<Space>D', '<Space>rn', '<Space>ca', '[d', ']d',
      \ '<Space>e', '<Space>q', '<Space>fls']
  call ExpectMap('lsp', 'n', s:m)
endfor
call ExpectMap('lsp', 'i', '<C-f>')
unlet s:m
call Expect('lsp:python', 'lsp#get_allowed_servers()', ['pyright'])
call Expect('lsp:yaml.ansible', 'lsp#get_allowed_servers()', ['ansiblels'])
call Expect('lsp:yaml.ansible', "get(b:, 'ale_linters', [])", ['ansible_lint'])
" ALE finds the trailing spaces in sample.yaml
call Scenario('ale', 'yamllint runs through ALE', [], "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/sample.yaml')", '',
      \ "WaitFor('len(ale#engine#GetLoclist(bufnr(\"%\"))) > 0', 20000)", 1)
" no tools on PATH: tier 2 still starts quietly and registers nothing
if !executable('pyright-langserver')
  call Expect('2', "has_key(g:myvim_lsp_servers, 'pyright')", 0)
endif
