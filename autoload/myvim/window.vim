" Window helpers (my-nvim core/options.lua, core/keymaps.lua, core/scripts.lua)

" Help windows take a third of the height they open with
function! myvim#window#help_height() abort
  execute 'resize' max([winheight(0) / 3, 5])
endfunction

" Move the preview window to the far right unless it already is rightmost
function! myvim#window#preview_right() abort
  if !exists('*win_screenpos')
    return
  endif
  let col = win_screenpos(0)[1]
  for w in range(1, winnr('$'))
    if w != winnr() && win_screenpos(w)[1] > col
      wincmd L
      return
    endif
  endfor
endfunction

" <C-W>{{: the tag under the cursor in a preview window on the far right
function! myvim#window#pedit_vertical() abort
  let &previewheight = winwidth(0) * 2 / 5
  execute 'pedit +/' . escape(expand('<cword>'), ' \/')
  wincmd P
  wincmd L
endfunction

" <C-P><C-D> / <C-P><C-U>: scroll the preview window half a page from anywhere
function! myvim#window#preview_scroll(dir) abort
  for w in range(1, winnr('$'))
    if getwinvar(w, '&previewwindow')
      let cur = winnr()
      noautocmd execute w . 'wincmd w'
      execute 'normal!' (a:dir ==# 'down' ? "\<C-D>" : "\<C-U>")
      noautocmd execute cur . 'wincmd w'
      return
    endif
  endfor
  echo 'No preview window found'
endfunction

" <leader>hi: syntax groups under the cursor (nvim's :Inspect)
function! myvim#window#inspect() abort
  let [l, c] = [line('.'), col('.')]
  let stack = map(synstack(l, c), 'synIDattr(v:val, "name")')
  echo (empty(stack) ? '(no syntax)' : join(stack, ' > ')) . ' -> ' . synIDattr(synIDtrans(synID(l, c, 1)), 'name')
endfunction
