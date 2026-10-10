" core/ansible.lua: yaml.ansible filetype and gf to role tasks
let s:a = "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/ansible/"
call Scenario('eval', 'role tasks are yaml.ansible', [], s:a . "roles/web/tasks/main.yml')", '', '&filetype', 'yaml.ansible')
call Scenario('eval', 'playbooks are yaml.ansible', [], s:a . "playbooks/site.yml')", '', '&filetype', 'yaml.ansible')
call Scenario('eval', 'other yaml stays yaml', [], "execute 'edit' fnameescape(g:myvim_root . '/tests/samples/sample.yaml')", '', '&filetype', 'yaml')
call Scenario('eval', 'gf on a role opens tasks/main.yml', [], s:a . "playbooks/site.yml')", '3G$gf', "expand('%:p:h:h:t') . '/' . expand('%:t')", 'web/main.yml')
call Scenario('eval', 'gf with tasks_from opens that file', [], s:a . "playbooks/site.yml')", '7G$gf', "expand('%:p:h:h:t') . '/' . expand('%:t')", 'web/extra.yml')
" own files: a changed sample buffer leaves a swap file that stops the next run
let s:g = '/tmp/myvim-gf'
silent! call mkdir(s:g . '/roles/web/tasks', 'p')
silent! call mkdir(s:g . '/playbooks', 'p')
call writefile(['x'], s:g . '/roles/web/tasks/extra.yml')
call writefile(['# ../roles/web/tasks/extra.yml'], s:g . '/playbooks/gf.yml')
call Scenario('eval', 'gf on a path relative to the file', [], 'edit ' . s:g . '/playbooks/gf.yml', '$gf', "expand('%:p')", s:g . '/roles/web/tasks/extra.yml')
unlet s:g
unlet s:a
