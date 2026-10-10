" Tier 2: vim-lsp (lspconfig), asyncomplete (nvim-cmp), ALE (nvim-lint and
" conform). Servers and tools are registered only when they are on PATH.
" This file loads before the plugins (plugin/ comes first in runtimepath),
" so their g: settings go here and the setup runs from their User events.
if !exists('g:myvim_tier') || g:myvim_tier < 2 || index(g:myvim_plugins, 'vim-lsp') < 0 | finish | endif

let g:myvim_lsp_servers = {}

" vim-lsp: diagnostics like my-nvim's vim.diagnostic.config
let g:lsp_diagnostics_virtual_text_enabled = 1
let g:lsp_diagnostics_virtual_text_align = 'after'
let g:lsp_diagnostics_echo_cursor = 1
let g:lsp_diagnostics_float_cursor = has('popupwin')
let g:lsp_document_highlight_enabled = 0
let g:lsp_signature_help_enabled = 1

" asyncomplete
let g:asyncomplete_auto_popup = 1
let g:asyncomplete_auto_completeopt = 0
set completeopt=menu,menuone,noselect

" ALE: lint and fix only; vim-lsp does the language servers
let g:ale_disable_lsp = 1
let g:ale_linters_explicit = 1
let g:ale_lint_on_text_changed = 'never'
let g:ale_lint_on_insert_leave = 1
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_javascript_eslint_executable = 'eslint_d'
let g:ale_javascript_eslint_use_global = 1
let g:ale_linters = {
  \ 'javascript': ['eslint'], 'typescript': ['eslint'], 'javascriptreact': ['eslint'],
  \ 'typescriptreact': ['eslint'], 'svelte': ['eslint'],
  \ 'python': ['pylint'], 'yaml': ['yamllint'], 'ansible': ['ansible_lint'], 'sh': ['shellcheck'],
  \ }
let s:prettier = ['javascript', 'typescript', 'javascriptreact', 'typescriptreact', 'svelte',
  \ 'css', 'html', 'json', 'yaml', 'markdown', 'graphql']
let g:ale_fixers = {}
for [s:tool, s:fts] in [['prettier', s:prettier], ['stylua', ['lua']], ['isort', ['python']], ['black', ['python']]]
  if executable(s:tool)
    for s:ft in s:fts
      let g:ale_fixers[s:ft] = get(g:ale_fixers, s:ft, []) + [s:tool]
    endfor
  endif
endfor
unlet! s:tool s:fts s:ft s:prettier

function! s:server(name, cmd, allow, ...) abort
  if !executable(a:cmd[0])
    return
  endif
  let info = {'name': a:name, 'cmd': a:cmd, 'allowlist': a:allow}
  if a:0
    call extend(info, a:1)
  endif
  call lsp#register_server(info)
  let g:myvim_lsp_servers[a:name] = a:allow
endfunction

function! s:setup() abort
  call s:server('pyright', ['pyright-langserver', '--stdio'], ['python'])
  call s:server('yamlls', ['yaml-language-server', '--stdio'], ['yaml'], {'blocklist': ['yaml.ansible']})
  call s:server('ansiblels', ['ansible-language-server', '--stdio'], ['yaml.ansible'])
  call s:server('bashls', ['bash-language-server', 'start'], ['sh', 'bash'])
  call s:server('lua_ls', ['lua-language-server'], ['lua'])
  call s:server('ts_ls', ['typescript-language-server', '--stdio'], ['javascript', 'javascriptreact', 'typescript', 'typescriptreact'])
  call s:server('html', ['vscode-html-language-server', '--stdio'], ['html'])
  call s:server('cssls', ['vscode-css-language-server', '--stdio'], ['css', 'scss', 'less'])
  call s:server('jsonls', ['vscode-json-language-server', '--stdio'], ['json'])
endfunction

function! s:on_buffer() abort
  let b:myvim_lsp = 1
  setlocal omnifunc=lsp#complete
  if exists('+tagfunc')
    setlocal tagfunc=lsp#tagfunc
  endif
  nmap <buffer> gd <plug>(lsp-definition)
  nmap <buffer> gD <plug>(lsp-declaration)
  nmap <buffer> gi <plug>(lsp-implementation)
  nmap <buffer> gr <plug>(lsp-references)
  nmap <buffer> K <plug>(lsp-hover)
  nmap <buffer> gK <plug>(lsp-signature-help)
  nnoremap <buffer> <silent> gl :call myvim#lsp#definition_in('right')<CR>
  nnoremap <buffer> <silent> gj :call myvim#lsp#definition_in('bottom')<CR>
  nmap <buffer> <leader>pd <plug>(lsp-peek-definition)
  nmap <buffer> <leader>pt <plug>(lsp-peek-type-definition)
  nmap <buffer> <leader>pi <plug>(lsp-peek-implementation)
  nmap <buffer> <leader>pD <plug>(lsp-peek-declaration)
  nmap <buffer> <leader>pr <plug>(lsp-references)
  nmap <buffer> <leader>pP <plug>(lsp-preview-close)
  imap <buffer> <C-f> <Esc><plug>(lsp-peek-definition)
  nmap <buffer> <leader>D <plug>(lsp-type-definition)
  nmap <buffer> <leader>rn <plug>(lsp-rename)
  nmap <buffer> <leader>ca <plug>(lsp-code-action)
  nmap <buffer> [d <plug>(lsp-previous-diagnostic)
  nmap <buffer> ]d <plug>(lsp-next-diagnostic)
  " vim-lsp has no single-line float command: both open the location list
  nmap <buffer> <leader>e <plug>(lsp-document-diagnostics)
  nmap <buffer> <leader>q <plug>(lsp-document-diagnostics)
  nmap <buffer> <leader>fls <plug>(lsp-document-symbol)
endfunction

function! s:complete_setup() abort
  call asyncomplete#register_source(asyncomplete#sources#buffer#get_source_options({
    \ 'name': 'buffer', 'allowlist': ['*'], 'completor': function('asyncomplete#sources#buffer#completor'),
    \ 'config': {'max_buffer_size': 5000000}}))
  call asyncomplete#register_source(asyncomplete#sources#file#get_source_options({
    \ 'name': 'file', 'allowlist': ['*'], 'priority': 10, 'completor': function('asyncomplete#sources#file#completor')}))
endfunction

augroup myvim_lsp
  autocmd!
  autocmd User lsp_setup call s:setup()
  autocmd User lsp_buffer_enabled call s:on_buffer()
  autocmd User asyncomplete_setup call s:complete_setup()
  " yaml.ansible: ansible-lint only (ALE would add yamllint for the yaml part)
  autocmd FileType yaml.ansible let b:ale_linters = ['ansible_lint']
augroup END

" global keys: ALE for buffers without a server, LSP start/stop/info
nnoremap <silent> <leader>ll :ALELint<CR>
nnoremap <silent> <leader>fm :ALEFix<CR>
" ALE fixes whole files; in visual mode too
xnoremap <silent> <leader>fm :<C-u>ALEFix<CR>
nmap [d <Plug>(ale_previous_wrap)
nmap ]d <Plug>(ale_next_wrap)
nnoremap <silent> <leader>e :ALEDetail<CR>
nnoremap <silent> <leader>lspe :call lsp#enable() <bar> edit<CR>
nnoremap <silent> <leader>lsps :LspStopServer<CR>
nnoremap <silent> <leader>lspI :LspStatus<CR>
inoremap <expr> <C-e> pumvisible() ? asyncomplete#cancel_popup() : "\<C-e>"
