scriptencoding utf-8
" vim: set ts=8 sts=2 sw=2 tw=0 :

if exists('loaded_PrjTree')
  finish
endif
let loaded_PrjTree = v:true

let s:save_cpo = &cpo
set cpo&vim


" netrwは常にtree view
let g:netrw_liststyle = 3
" ファイルのプレビューを垂直分割で開く。
let g:netrw_preview   = 1
"
let g:netrw_sort_by='name'
let g:netrw_sort_sequence='[\/]$,\.sw\a$'
let g:netrw_special_syntax=v:true
let g:netrw_browse_split=0
let g:netrw_browse_split=4


let g:PrjTree_RootFile = get(g:, 'prj_root_file', '.git')


set autochdir


function! s:wipeout_old_NetrwTree_buf()
  for i in range(1, bufnr('$'))
    let name = bufname(i)
    if match(name, 'NetrwTreeListing\( \d\+\)\?$') != -1
      try
        exe 'bwipeout ' i
      catch
      endtry
    endif
  endfor
endfunction


function! MyExplore()
  let g:filename = expand('%')
  let g:pwd = getcwd(win_getid())

  " search root dir
  let root = ''
  for i in range(6)
    if filereadable(g:PrjTree_RootFile) || isdirectory(g:PrjTree_RootFile)
      " win 2 unix
      let root = substitute(getcwd(), '\\', '/', 'g')
      break
    endif
    cd ..
  endfor
  exe 'cd ' . g:pwd
  let n = (root == '' ? 0 : i)

  " check exist root dir win
  for i in range(1, winnr('$'))
    let name = bufname(winbufnr(i))
    if match(name, 'NetrwTreeListing\( \d\+\)\?$') != -1
      if root == substitute(getcwd(i), '\\', '/', 'g')
        " exist root dir win
        exe i . 'wincmd w'
        return
      endif
    endif
  endfor

  call <SID>wipeout_old_NetrwTree_buf()

  Lexplore
  exe 'cd ' . root

  if n > 0
    " Netrwバッファのmapに展開する必要があるので、!は付けない。
    exe 'silent normal ' . repeat("-", n)
  endif

  " move cursor to org file
  call search('\%(' . repeat('│ ', n) . '\)\@<=' . g:filename . '$', 'cw')
endfunction


com! MyExplore call MyExplore()

nnoremap <silent> <leader>t :<C-u>MyExplore<CR>


let &cpo = s:save_cpo
unlet s:save_cpo
