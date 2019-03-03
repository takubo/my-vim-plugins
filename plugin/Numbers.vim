scriptencoding utf-8
" vim: set ts=8 sts=2 sw=2 tw=0 :

if exists('loaded_Numbers')
  finish
endif
let loaded_Numbers = v:true

let s:save_cpo = &cpo
set cpo&vim


let g:em_use_octal = v:false
let g:em_extend_bin = v:true
let g:em_extend_dec = v:false
let g:em_extend_hex = v:false


let s:b2h = { '0000' : '0', '0001' : '1', '0010' : '2', '0011' : '3', '0100' : '4', '0101' : '5', '0110' : '6', '0111' : '7',
            \ '1000' : '8', '1001' : '9', '1010' : 'a', '1011' : 'b', '1100' : 'c', '1101' : 'd', '1110' : 'e', '1111' : 'f' }

let s:h2b_dsip = { '0' : 'oooo', '1' : 'oooI', '2' : 'ooIo', '3' : 'ooII', '4' : 'oIoo', '5' : 'oIoI', '6' : 'oIIo', '7' : 'oIII',
                 \ '8' : 'Iooo', '9' : 'IooI', 'a' : 'IoIo', 'b' : 'IoII', 'c' : 'IIoo', 'd' : 'IIoI', 'e' : 'IIIo', 'f' : 'IIII' }

let s:h2b_norm = { '0' : '0000', '1' : '0001', '2' : '0010', '3' : '0011', '4' : '0100', '5' : '0101', '6' : '0110', '7' : '0111',
                 \ '8' : '1000', '9' : '1001', 'a' : '1010', 'b' : '1011', 'c' : '1100', 'd' : '1101', 'e' : '1110', 'f' : '1111' }

let s:now_disp = 0


function! s:ana_numstr(word)
  let rawstr = a:word
  let numstr = ''
  let base = 0

  if rawstr =~? '^0x\x\+[lLuU]\{,3\}$'	" long long型リテラルは、0x56LLのようにLが2つ付く
    let base = 16
    let numstr = substitute(strpart(rawstr, 2), '[ulUL]\+', '', '')
  elseif rawstr =~? '^\([1-9]\d*\|0\+\)[lLuU]\{,3\}$'	" 0のみから構成される数は、Cの仕様上、厳密には8進であるが、便宜上10進として扱う。
    let base = 10
    let numstr = substitute(rawstr, '[ulUL]\+', '', '')
  elseif g:em_use_octal && rawstr =~? '^0\o\+$'
    let base = 8
    let numstr = rawstr
  elseif rawstr =~? '^0b[01]\+$'  " 2進リテラル(C99)
    let base = 2
    let numstr = strpart(rawstr, 2)
  elseif g:em_extend_bin && rawstr =~? '^\(0b\)\?[_01]\{3,\}$'  " Cの接頭辞がない2進数 および 桁区切りにアンダースコアを使う2進数
    let base = 2
    let numstr = substitute(rawstr, '^0b\|_', '', 'g')
  elseif g:em_extend_hex && rawstr =~? '^\x\+$'  " Cの接頭辞がない16進数
    let base = 16
    let numstr = rawstr
  elseif g:em_extend_dec && rawstr =~? '^\([0-9,]\+\)$'  " 桁区切りにカンマを使う10進数
    let base = 10
    let numstr = substitute(rawstr, '^0\+\|,', '', 'g')
  elseif !g:em_use_octal && rawstr =~? '^\([0-9]\+\)$'  " 0で始まる10進数
    let base = 10
    let numstr = substitute(rawstr, '^0\+\|,', '', 'g')
  endif

  let ret = {'rawstr':rawstr, 'numstr':numstr, 'base':base}
  return ret
endfunc


function! s:hex_add_leading_zero(hex)
  let hex_len = len(a:hex)
  let hex = hex_len == 1 ? '0' . a:hex :
          \ hex_len == 3 ? '0' . a:hex :
          \ hex_len > 4 && hex_len <  8 ? matchstr('000' . a:hex, '.\{8\}$') :
          \ hex_len > 8 && hex_len < 16 ? matchstr('0000000' . a:hex, '.\{16\}$') :
          \ a:hex
  return hex
endfunction


function! s:hex2bin(hex, disp)
  let h2b = a:disp ? s:h2b_dsip : s:h2b_norm

  let bin = ''
  for i in split(a:hex, '\zs')
    let bin .= h2b[tolower(i)] . ' '
  endfor

  return bin
endfunc


function! Bin2Dec(bin)
  return Hex2Dec(Bin2Hex(a:bin))
endfunction


function! Bin2Hex(bin)
  let bin = a:bin

  let hex = ''
  while len(bin) > 0
    let tmp = matchstr('000' . strpart(bin, len(bin) - 4), '....$')
    let hex = s:b2h[tmp] . hex
    let bin = substitute(bin, '[01]\{0,4\}$', '', '')
  endwhile

  return s:hex_add_leading_zero(hex)
endfunc


function! Dec2Bin(dec)
  return s:hex2bin(Dec2Hex(a:dec), v:false)
endfunc


function! Dec2Hex(dec)
  if has('python3')
    python3 vim.command('let hex = "' + format(int(vim.eval('a:dec'), 10), 'x') + '"')
  else
    let hex = printf("%08x", a:dec)
  endif
  return s:hex_add_leading_zero(hex)
endfunc


function! Hex2Bin(hex)
  return s:hex2bin(a:hex, v:false)
endfunction


function! Hex2Dec(hex)
  if has('python3')
    python3 vim.command('let dec = "' + str(int(vim.eval('a:hex'), 16)) + '"')
  else
    let dec = printf("%u", (a:hex[0:1] != '0x' ? '0x' : '') . a:hex)
  endif
  return dec
endfunction


function! s:EmDisp(word)
  let r = s:ana_numstr(a:word)

  let dig = len(r.numstr)

  if r.base == 16
    let dec = Hex2Dec(r.numstr)
    let bin = s:hex2bin(r.numstr, v:true)
    let byt = len(r.numstr) / 2
    let bit = len(substitute(bin, '^[ o]\+\| ', '', 'g'))
    echo ' [Dec]' dec '    [Bin]' bin '' (winwidth(0) > 100 ? '    ' : '\n') '[Byt]' byt '    [Bit]' bit '    [Dig]' dig
    let s:now_disp = 1

  elseif r.base == 10
    let hex = Dec2Hex(r.numstr)
    let bin = s:hex2bin(hex, v:true)
    let byt = float2nr(ceil(len(hex) / 2.0))
    let bit = len(substitute(bin, '^[ o]\+\| ', '', 'g'))
    echo ' [Hex] 0x' . hex '    [Bin]' bin  '' (winwidth(0) > 100 ? '    ' : '\n') '[byt]' byt '    [Bit]' bit '    [Dig]' dig
    let s:now_disp = 1

  elseif r.base == 2
    let hex = Bin2Hex(r.numstr)
    let dec = Hex2Dec(hex)
    let byt = float2nr(ceil(len(r.numstr) / 8.0))
    let bit = len(substitute(r.numstr, '^0\+', '', ''))
    echo ' [Hex] 0x' . hex '    [Dec] ' dec '    [byt]' byt '    [Bit]' bit '    [Dig]' dig
    let s:now_disp = 1

  elseif s:now_disp
    echo ''
    let s:now_disp = 0
  endif
endfun


command! EmDisp :call <SID>EmDisp(expand("<cword>"))

command! EmExtendTgl :let g:em_extend_bin = !g:em_extend_bin <Bar> let g:em_extend_dec = !g:em_extend_dec <Bar> let g:em_extend_hex = !g:em_extend_hex

augroup Numbers
  au!
  au CursorMoved,VimResized * EmDisp
  au CmdwinEnter * let <SID>now_disp = 0
augroup end


inoremap <C-r><C-b><C-d> <C-r>=Bin2Dec('')<Left><Left>
inoremap <C-r><C-b><C-h> <C-r>=Bin2Hex('')<Left><Left>
inoremap <C-r><C-b><C-x> <C-r>=Bin2Hex('')<Left><Left>
inoremap <C-r><C-d><C-b> <C-r>=Dec2Bin('')<Left><Left>
inoremap <C-r><C-d><C-x> <C-r>=Dec2Hex('')<Left><Left>
inoremap <C-r><C-d><C-h> <C-r>=Dec2Hex('')<Left><Left>
inoremap <C-r><C-h><C-b> <C-r>=Hex2Bin('')<Left><Left>
inoremap <C-r><C-h><C-d> <C-r>=Hex2Dec('')<Left><Left>
inoremap <C-r><C-x><C-b> <C-r>=Hex2Bin('')<Left><Left>
inoremap <C-r><C-x><C-d> <C-r>=Hex2Dec('')<Left><Left>


function! s:cmd_driver(from, to, ...)
  let n = ( a:0 == 0 ? @" : a:1 )
  if n == ''
    echoerr 'no target.'
    return ''
  endif
  let n = substitute(n, '^0[bx]\|[lLuU\n]*$', '', '')
  let n = substitute(n, '[ ,_]', '', 'g')
  let m = {a:from . '2' . a:to}(n)
  let m = substitute(m, ' ', '', 'g')
  let m = (a:to == 'hex' ? '0x' : '') . m
  return m
endfunction


command! -nargs=? BD exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Bin', 'Dec', <f-args>) . "\<Esc>"
command! -nargs=? BH exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Bin', 'Hex', <f-args>) . "\<Esc>"
command! -nargs=? BX exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Bin', 'Hex', <f-args>) . "\<Esc>"
command! -nargs=? DB exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Dec', 'Bin', <f-args>) . "\<Esc>"
command! -nargs=? DH exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Dec', 'Hex', <f-args>) . "\<Esc>"
command! -nargs=? DX exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Dec', 'Hex', <f-args>) . "\<Esc>"
command! -nargs=? HB exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Hex', 'Bin', <f-args>) . "\<Esc>"
command! -nargs=? XB exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Hex', 'Bin', <f-args>) . "\<Esc>"
command! -nargs=? HD exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Hex', 'Dec', <f-args>) . "\<Esc>"
command! -nargs=? XD exe 'normal! ' . (search('^\%#$', 'cn') ? 'i' : 'ciw') . s:cmd_driver('Hex', 'Dec', <f-args>) . "\<Esc>"


"" Test

command! EmTestAnaNum :echo s:ana_numstr(expand("<cword>"))

" 0xaf45 0xf0 0b011100 0716 1234 65535 0xfdb97531 0xfdb97531ff 256 0b111111110000000011010000  0101111
" 0xaf45UL 0xf0ll 0b011100 0716 1234 65536 0xfdb97531 256a 0b111111110000000011010000  0101111
" 98,67878,2345 0b01011111000000001101_0000 0xffffffffffffffff 0xffffffffffffffffffffffffffffffff
" 0b11 993692464862809801080805478547854754953675 3 165535 18446744073709551606


"" TODO
"	シェル版の奇数変換コマンドの全てのオプションに対応


let &cpo = s:save_cpo
unlet s:save_cpo
