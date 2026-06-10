if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

command! -buffer LlRainbow call s:ToggleRainbow()

function! s:ToggleRainbow()
  let g:ll_rainbow = !get(g:, 'll_rainbow', 1)
  set syntax=ll
endfunction

nnoremap <buffer> <LocalLeader>r :LlRainbow<CR>
