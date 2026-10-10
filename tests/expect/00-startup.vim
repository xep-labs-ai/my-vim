" Startup: the config loaded, at the expected tier, with a state dir and leader.
call Expect('eval', "exists('g:myvim_tier')", 1)
if !empty($PROBE_TIER)
  call Expect('eval', "get(g:, 'myvim_tier', -1)", str2nr($PROBE_TIER))
endif
call Expect('eval', "isdirectory(get(g:, 'myvim_state', '/nonexistent') . '/undo')", 1)
call Expect('eval', "get(g:, 'mapleader', '')", ' ')
