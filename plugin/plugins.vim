" Settings and keymaps of the vendored plugins (tier 1). Same keys as
" my-nvim's lazy_plugins/*.lua; LSP keys are in plugin/lsp.vim.
if !exists('g:myvim_tier') || g:myvim_tier < 1 | finish | endif

" look: nightfly + lualine's colours in lightline (bufferline ran in tabs mode)
let g:nightflyCursorColor = 1
let g:nightflyWinSeparator = 2
if &encoding ==# 'utf-8'
  set fillchars+=vert:┃
endif
augroup myvim_colors
  autocmd!
  autocmd ColorScheme * call myvim#colors#overrides()
augroup END
" nightfly sets termguicolors itself: vimrc loads it only where that exists
if index(g:myvim_plugins, 'vim-nightfly-colors') >= 0
  colorscheme nightfly
endif
let g:lightline = {
  \ 'colorscheme': 'myvim',
  \ 'active': {
  \   'left': [['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified']],
  \   'right': [['lineinfo'], ['percent'], ['fileencoding', 'fileformat', 'filetype']],
  \ },
  \ 'component_function': {'gitbranch': 'FugitiveHead'},
  \ 'tabline': {'left': [['tabs']], 'right': []},
  \ }
set noshowmode
set showtabline=2

" finders (telescope): fzf.vim with a recent fzf, else ctrlp and :grep
let g:ctrlp_use_caching = 0
let g:ctrlp_working_path_mode = ''
if g:myvim_fzf
  if empty($FZF_DEFAULT_COMMAND) && executable('rg')
    let $FZF_DEFAULT_COMMAND = 'rg --files'
  endif
  let $FZF_DEFAULT_OPTS = $FZF_DEFAULT_OPTS . ' --bind=ctrl-j:down,ctrl-k:up'
endif
nnoremap <silent> <leader>ff :call myvim#find#files(0)<CR>
nnoremap <silent> <leader>fF :call myvim#find#files(1)<CR>
nnoremap <silent> <leader>fs :call myvim#find#grep(0)<CR>
nnoremap <silent> <leader>fc :call myvim#find#grep(1)<CR>
nnoremap <silent> <leader>fe :call myvim#find#in_file()<CR>
nnoremap <silent> <leader>fgb :call myvim#find#git_branches()<CR>
if g:myvim_fzf
  nnoremap <silent> <leader>fb :Buffers<CR>
  nnoremap <silent> <leader>fh :Helptags<CR>
  nnoremap <silent> <leader>fht :Helptags<CR>
  nnoremap <silent> <leader>fg :GFiles<CR>
  nnoremap <silent> <leader>fgf :GFiles<CR>
  nnoremap <silent> <leader>fgs :GFiles?<CR>
  nnoremap <silent> <leader>fgc :Commits<CR>
else
  nnoremap <silent> <leader>fb :CtrlPBuffer<CR>
  nnoremap <leader>fh :help<Space>
  nnoremap <leader>fht :help<Space>
  nnoremap <silent> <leader>fg :call myvim#find#files(0)<CR>
  nnoremap <silent> <leader>fgf :call myvim#find#files(0)<CR>
  nnoremap <silent> <leader>fgs :Git<CR>
  nnoremap <silent> <leader>fgc :Git log --oneline --decorate -50<CR>
endif
nnoremap <silent> <leader>fu :UndotreeToggle<CR>

" git (neogit / diffview -> fugitive), gitsigns -> gitgutter
nnoremap <silent> <leader>fgdw :Git diff<CR>
nnoremap <silent> <leader>fgdfc :0Gclog<CR>
nnoremap <silent> <leader>fgdfa :Gclog<CR>
let g:gitgutter_map_keys = 0

" file tree (nvim-tree -> NERDTree)
let g:NERDTreeWinSize = 30
let g:NERDTreeShowHidden = 1
let g:NERDTreeIgnore = ['^\.git$']
nnoremap <silent> <leader>ee :NERDTreeToggle<CR>
nnoremap <silent> <leader>ef :call myvim#tree#find_toggle()<CR>
nnoremap <silent> <leader>ec :call myvim#tree#collapse()<CR>
nnoremap <silent> <leader>er :call myvim#tree#refresh()<CR>
nnoremap <silent> <leader>ea :call myvim#tree#expand_all()<CR>

" undotree, maximizer
let g:undotree_WindowLayout = 3
nnoremap <silent> <leader>ut :UndotreeToggle<CR>
nnoremap <silent> <leader>up :UndotreePersistUndo<CR>
nnoremap <silent> <leader>sm :MaximizerToggle<CR>

" outline (outline.nvim -> vista): vista follows the cursor by itself
let g:vista_default_executive = g:myvim_tier >= 2 ? 'vim_lsp' : 'ctags'
let g:vista#renderer#enable_icon = 0
nnoremap <silent> <leader>mo :Vista!!<CR>
nnoremap <silent> <leader>mf :Vista focus<CR>

" auto-pairs: no Alt shortcuts (harpoon has <M-p>/<M-n>/<M-e>), <CR> is ours
let g:AutoPairsShortcutToggle = ''
let g:AutoPairsShortcutFastWrap = ''
let g:AutoPairsShortcutJump = ''
let g:AutoPairsShortcutBackInsert = ''
let g:AutoPairsMapCR = 0
set completeopt=menu,menuone,noselect
inoremap <silent> <expr> <CR> myvim#complete#cr()

" indent guides (indent-blankline): one colour; conceal would hide quotes
let g:indentLine_char = '│'
let g:indentLine_color_gui = '#61AFEF'
let g:indentLine_color_term = 75
let g:indentLine_fileTypeExclude = ['json', 'jsonc', 'markdown', 'help', 'nerdtree', 'undotree', 'vista']
let g:indentLine_bufTypeExclude = ['help', 'terminal', 'nofile']
let g:vim_json_conceal = 0
let g:vim_json_syntax_conceal = 0
let g:markdown_syntax_conceal = 0
" conceallevel is per window: indentLine leaves 2 behind for the excluded
" filetypes, and vim 8.0's json syntax always conceals quotes
augroup myvim_conceal
  autocmd!
  autocmd FileType json,jsonc,markdown setlocal conceallevel=0
augroup END

" terminal (toggleterm)
if has('terminal')
  nnoremap <silent> <leader>ttt :call myvim#term#toggle('tab')<CR>
  nnoremap <silent> <leader>ttv :call myvim#term#toggle('split')<CR>
  tnoremap <silent> <C-h> <C-w>h
  tnoremap <silent> <C-j> <C-w>j
  tnoremap <silent> <C-k> <C-w>k
  tnoremap <silent> <C-l> <C-w>l
endif
