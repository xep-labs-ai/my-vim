" Clipboard: see autoload/myvim/clip.vim and the spec's "Clipboard and tmux".
if !exists('g:myvim_tier') | finish | endif

let g:myvim_clip_mode = get(g:, 'myvim_clip_mode', myvim#clip#mode())
if g:myvim_clip_mode ==# 'system'
  set clipboard^=unnamedplus
elseif g:myvim_clip_mode !=# 'none'
  if exists('##TextYankPost')
    augroup myvim_clip
      autocmd!
      autocmd TextYankPost * call myvim#clip#on_yank(copy(v:event))
    augroup END
  endif
  if g:myvim_clip_mode ==# 'tmux'
    for s:k in ['p', 'P', 'gp', 'gP']
      execute 'nnoremap <silent> ' . s:k . ' :<C-u>call myvim#clip#put(' . string(s:k) . ', v:count1, v:register, 0)<CR>'
      execute 'xnoremap <silent> ' . s:k . ' :<C-u>call myvim#clip#put(' . string(s:k) . ', v:count1, v:register, 1)<CR>'
    endfor
    unlet s:k
  endif
endif

command! MessagesToClipboard call myvim#clip#messages()
