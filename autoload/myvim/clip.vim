" Clipboard for servers (spec: "Clipboard and tmux"). Like my-nvim's
" clipboard=unnamedplus with nvim's tmux provider:
"   tmux   yank -> tmux buffer + client clipboard; p -> tmux buffer first
"   osc52  yank -> OSC 52 straight to the terminal
"   system yank/paste through vim's own +clipboard

" what vim last sent: {'text', 'lines', 'type'}; p restores this exact
" register (blockwise stays blockwise) when the tmux buffer still holds it
let s:last = {'text': '', 'lines': [], 'type': 'v'}
let s:tmux_version = -1

function! myvim#clip#mode() abort
  if has('clipboard') && (has('mac') || has('macunix') || !empty($DISPLAY) || !empty($WAYLAND_DISPLAY))
    return 'system'
  elseif !empty($TMUX) && executable('tmux')
    return 'tmux'
  elseif !has('gui_running')
    return 'osc52'
  endif
  return 'none'
endfunction

" tmux version as major * 100 + minor (3.2 -> 302), 0 if unknown
function! s:tmux_version() abort
  if s:tmux_version < 0
    let v = matchlist(system('tmux -V'), '\(\d\+\)\.\(\d\+\)')
    let s:tmux_version = empty(v) ? 0 : str2nr(v[1]) * 100 + str2nr(v[2])
  endif
  return s:tmux_version
endfunction

" tmux 3.2+ has load-buffer -w and refresh-client -l
function! s:tmux32() abort
  return s:tmux_version() >= 302
endfunction

function! s:osc52(text, passthrough) abort
  let seq = "\e]52;c;" . substitute(system('base64', a:text), '\n', '', 'g') . "\x07"
  if a:passthrough
    let seq = "\ePtmux;" . substitute(seq, "\e", "\e\e", 'g') . "\e\\"
  endif
  if exists('*echoraw')
    call echoraw(seq)
  elseif filewritable('/dev/tty')
    call writefile([seq], '/dev/tty', 'b')
  endif
endfunction

function! s:send(text) abort
  let mode = get(g:, 'myvim_clip_mode', 'none')
  if mode ==# 'system'
    call setreg('+', a:text)
  elseif mode ==# 'tmux'
    if s:tmux32()
      call system('tmux load-buffer -w -', a:text)
    elseif s:tmux_version() >= 200
      call system('tmux load-buffer -', a:text)
      call s:osc52(a:text, 1)
    else
      " tmux 1.x hangs reading stdin from a file, which is how system() gives
      " it the text: load a temp file instead (the tmux server reads it)
      let tmp = tempname()
      call writefile(split(a:text, "\n", 1), tmp, 'b')
      call system('tmux load-buffer ' . shellescape(tmp))
      call delete(tmp)
      call s:osc52(a:text, 1)
    endif
  elseif mode ==# 'osc52'
    call s:osc52(a:text, 0)
  endif
endfunction

" <leader>yy*, :MessagesToClipboard
function! myvim#clip#copy(text) abort
  let s:last = {'text': a:text, 'lines': split(a:text, "\n", 1), 'type': 'v'}
  call s:send(a:text)
endfunction

" TextYankPost: what unnamedplus copies, yanks and deletes into the unnamed register
function! myvim#clip#on_yank(event) abort
  if a:event.regname !=# '' && a:event.regname !=# '"'
    return
  endif
  let text = join(a:event.regcontents, "\n") . (a:event.regtype ==# 'V' ? "\n" : '')
  let s:last = {'text': text, 'lines': copy(a:event.regcontents), 'type': a:event.regtype}
  call s:send(text)
endfunction

" Set the unnamed register from the tmux buffer, asking the client terminal
" for its clipboard first (tmux 3.2+), like nvim's tmux provider
function! s:pull() abort
  if s:tmux32()
    call system('tmux refresh-client -l')
  endif
  let text = system('tmux save-buffer -')
  if v:shell_error || empty(text)
    return
  endif
  if text ==# s:last.text
    call setreg('"', s:last.lines, s:last.type)
    return
  endif
  let lines = split(text, "\n", 1)
  if text =~# "\n$"
    call remove(lines, -1)
    call setreg('"', lines, 'V')
  else
    call setreg('"', lines, 'v')
  endif
endfunction

" p P gp gP (normal and visual) in tmux mode
function! myvim#clip#put(key, count, reg, visual) abort
  if a:reg ==# '"'
    call s:pull()
  endif
  execute 'normal! ' . (a:visual ? 'gv' : '') . a:count . '"' . a:reg . a:key
endfunction

" :MessagesToClipboard (core/scripts.lua)
function! myvim#clip#messages() abort
  redir => msgs
  silent messages
  redir END
  call myvim#clip#copy(msgs)
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile
  call setline(1, split(msgs, "\n"))
  echo 'Messages copied to clipboard and opened in new buffer.'
endfunction
