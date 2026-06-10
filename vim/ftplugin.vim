if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

command! -buffer LRainbow call s:ToggleRainbow()

function! s:ToggleRainbow()
  let g:l_rainbow = !get(g:, 'l_rainbow', 1)
  set syntax=l
endfunction

nnoremap <buffer> <LocalLeader>r :LRainbow<CR>
