" Highlight overrides from my-nvim's colorscheme.lua and nvim-tree.lua
function! myvim#colors#overrides() abort
  highlight CursorLine gui=NONE cterm=NONE guibg=#202d69 ctermbg=17
  highlight DiffAdd guifg=#81b88b guibg=NONE ctermfg=108 ctermbg=NONE
  highlight DiffChange guifg=#e2c08d guibg=NONE ctermfg=180 ctermbg=NONE
  highlight DiffText guifg=#c586c0 guibg=NONE gui=bold ctermfg=176 ctermbg=NONE cterm=bold
  highlight DiffDelete guifg=#c74e39 guibg=NONE ctermfg=167 ctermbg=NONE
  highlight NERDTreeOpenable guifg=#3FC5FF ctermfg=81
  highlight NERDTreeClosable guifg=#3FC5FF ctermfg=81
endfunction
