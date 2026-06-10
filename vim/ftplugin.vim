if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

command! -buffer LoveRainbow call s:ToggleRainbow()

function! s:ToggleRainbow()
  let g:love_rainbow = !get(g:, 'l_rainbow', 1)
  set syntax=l
endfunction

nnoremap <buffer> <LocalLeader>r :LoveRainbow<CR>
