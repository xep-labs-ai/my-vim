" gf that knows Ansible roles (core/ansible.lua)
if !exists('g:myvim_tier') | finish | endif
nnoremap <buffer> <silent> gf :call myvim#ansible#gf()<CR>
let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe') . ' | silent! nunmap <buffer> gf'
