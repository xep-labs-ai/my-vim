" yaml.ansible for playbooks and role tasks (core/ansible.lua). Runs after
" vim's own yaml detection, so `set filetype` (not setfiletype) wins.
autocmd BufRead,BufNewFile */playbooks/*.yml,*/playbooks/*.yaml,*/roles/*/tasks/*.yml,*/roles/*/tasks/*.yaml,*/ansible/*.yml,*/ansible/*.yaml set filetype=yaml.ansible
