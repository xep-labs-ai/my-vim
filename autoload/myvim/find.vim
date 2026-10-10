" <leader>f* finders: fzf.vim when g:myvim_fzf, else ctrlp and :grep

" files under DIR ('.' for fzf, '%s' for ctrlp's user_command)
function! s:list_cmd(hidden, dir) abort
  if executable('rg')
    return 'rg --files' . (a:hidden ? ' --hidden --no-ignore --follow ' : ' ') . a:dir
  endif
  return a:hidden ? 'find -L ' . a:dir . ' -type f' : 'find ' . a:dir . " -type f -not -path '*/.git/*'"
endfunction

" files(hidden [, query]): a query opens the only match straight away
function! myvim#find#files(hidden, ...) abort
  let query = a:0 ? a:1 : ''
  if g:myvim_fzf
    let spec = {'source': s:list_cmd(a:hidden, '.')}
    if !empty(query)
      let spec.options = ['--query', query, '--select-1']
    endif
    call fzf#vim#files('', spec)
  else
    let g:ctrlp_user_command = s:list_cmd(a:hidden, '%s')
    let g:ctrlp_default_input = query
    CtrlP
    let g:ctrlp_default_input = ''
  endif
endfunction

" grep(word): live grep (0) or the word under the cursor (1)
function! myvim#find#grep(word) abort
  if g:myvim_fzf && executable('rg')
    if a:word
      call fzf#vim#grep('rg --column --line-number --no-heading --color=always --smart-case -- ' . shellescape(expand('<cword>')), {})
    else
      RG
    endif
    return
  endif
  let pat = a:word ? expand('<cword>') : input('Grep > ')
  if empty(pat)
    return
  endif
  execute 'silent grep!' shellescape(pat, 1)
  redraw!
  botright cwindow
endfunction

" search in the current file
function! myvim#find#in_file() abort
  if g:myvim_fzf
    BLines
    return
  endif
  let pat = input('Search in file > ')
  if empty(pat)
    return
  endif
  execute 'silent! lvimgrep /' . escape(pat, '/') . '/j %'
  lwindow
endfunction

function! myvim#find#git_branches() abort
  if g:myvim_fzf
    call fzf#run(fzf#wrap({'source': "git branch --all --format='%(refname:short)'", 'sink': function('s:switch')}))
  else
    Git branch --all
  endif
endfunction

function! s:switch(branch) abort
  execute 'Git switch' substitute(a:branch, '^origin/', '', '')
endfunction
