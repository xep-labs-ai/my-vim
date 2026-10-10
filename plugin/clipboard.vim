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
  " without TextYankPost, yanks never reach the tmux buffer: p reading it
  " would paste something older than what was just yanked
  if g:myvim_clip_mode ==# 'tmux' && exists('##TextYankPost')
    for s:k in ['p', 'P', 'gp', 'gP']
      execute 'nnoremap <expr> ' . s:k . ' myvim#clip#pull_for(v:register) . ' . string(s:k)
      execute 'xnoremap <expr> ' . s:k . ' myvim#clip#pull_for(v:register) . ' . string(s:k)
    endfor
    unlet s:k
  endif
endif

command! MessagesToClipboard call myvim#clip#messages()
