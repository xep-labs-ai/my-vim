" Startup: the config loaded, at the expected tier, with a state dir and leader.
call Expect('eval', "exists('g:myvim_tier')", 1)
if !empty($PROBE_TIER)
  call Expect('eval', "get(g:, 'myvim_tier', -1)", str2nr($PROBE_TIER))
endif
call Expect('eval', "isdirectory(get(g:, 'myvim_state', '/nonexistent') . '/undo')", 1)
call Expect('eval', "get(g:, 'mapleader', '')", ' ')
call Expect('eval', '&g:tabstop', 2)
call Expect('eval', '&relativenumber', 1)
call Expect('eval', "get(g:, 'myvim_fzf_min', '')", '0.63')
call Expect('eval', "type(get(g:, 'myvim_plugins', 0))", type([]))
call Expect('1', "exists('g:did_load_filetypes')", 1)
call Expect('1', "exists('g:syntax_on')", 1)
" the readonly case: the state dir must fall back outside the repo
if filewritable(get(g:, 'myvim_root', '/') . '/vimrc') != 1
  call Expect('eval', "stridx(get(g:, 'myvim_state', ''), '/.local/state/my-vim') > 0", 1)
endif
