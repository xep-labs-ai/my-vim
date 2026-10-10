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
