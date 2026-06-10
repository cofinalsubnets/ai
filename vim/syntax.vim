" vim syntax for ll lisp (.l)
" based on lisp.vim by Charles E Campbell <http://www.drchip.org/astronaut/vim/index.html#SYNTAX_LISP>
if exists("b:current_syntax")
  finish
endif

" symbol-constituent chars (the reader ends a token only on whitespace and
" ( ) " ' ` , # ; ). operators @ # $ are excluded so they highlight standalone;
" % is a plain symbol now (the infix mod alias).
"  33 !  37 %  38 &  42 *  43 +  45 -  46 .  47 /  48-57 digits  58 :
"  60-63 < = > ?  92 \  94 ^  95 _  124 |  126 ~   (@ = alphabetics)
syn iskeyword @,33,37,38,42-43,45-47,48-57,58,60-63,92,94-95,124,126

" The three special forms: : (letrec*/seq), ? (cond), \ (lambda/quote)
syn keyword LlForm : ? \\

" Built-in functions (C nifs) + prelude functions
syn keyword LlFunc cons cap cbp caap cabp cbap cbbp
syn keyword LlFunc caaap caabp cabap cabbp cbaap cbabp cbbap cbbbp
syn keyword LlFunc id co const flip
syn keyword LlFunc map foldl foldr foldl1 foldr1 filter init last each all any cat catmap
syn keyword LlFunc rev take drop part zip ldel assq memq lidx sort sortsplit merge
syn keyword LlFunc + - * / % mod < <= = >= > <- -> idp sortl msort inc dec abs gcd modpow int
syn keyword LlFunc ~ << >> & \| ^
syn keyword LlFunc sin cos log pow plex re im conj arg clift
syn keyword LlFunc nump intp powg num-ap numfn randint
syn keyword LlFunc twop strp symp mapp lamp handlep tupp bigp boxp arrp comp flop fixp nilp atomp
syn keyword LlFunc arr array arank alen ashape atype asum aprod amax amin aall
syn keyword LlFunc a-rank a-shape a-type a-dim
syn keyword LlFunc string ssub scat intern nom slurp show sip pad page
syn keyword LlFunc hashn hashk hashd digest sat peek pin pull buf blit
syn keyword LlFunc lam peekl pinl seekl trim
syn keyword LlFunc fgetc fungetc feof fputc fputs fputn fputx fflush fread
syn keyword LlFunc putc puts putn putx getc read in out dot
syn keyword LlFunc ev call-cc yield spawn wait sleep done? kill key?
syn keyword LlFunc trap sing? more? eof?
syn keyword LlFunc rand randf rand-next randf-next rng-seed rng-get rng-set
syn keyword LlFunc open close run getenv exit
syn keyword LlFunc clock vminfo dict macros assert version-number argv cmdline

" Macros (head-symbol rewrites installed with ::)
syn keyword LlMacro :: L list do begin progn let if cond quote qq gsym tuple hash
syn keyword LlMacro && \|\| :- ?- >>= <=<

" Constants: booleans (1/0), the tier-spine array element-kind codes, e pi i
syn keyword LlConst true false e pi i
syn keyword LlConst z r c o

" Quoted atoms: 'foo   (' is one-operand \ = quote)
syn match LlAtomMark "'"
syn match LlAtom "'[^ \t\n()`',;#\"]\+" contains=LlAtomMark

" Quasiquote marks: `tmpl  ,unquote  ,@unquote-splice
syn match LlQuasi ",@\|[`,]"

" Prefix operators: @(…) array  #(…) hash  $x sat  (table: dict['operators])
syn match LlSigil "[@#$]"

" Numbers (integer / bignum literals, possibly negative)
syn match LlNumber "\<-\?\d\+\>"

" Floating point literals: 1.5  -1.5  .5  1.  1e10  1.5e-3  (a point and/or exponent)
" Defined after LlNumber so a float wins over the integer match at a shared start.
syn match LlFloat "\<-\?\d\+\.\d*\([eE][-+]\?\d\+\)\?\>"
syn match LlFloat "\<-\?\.\d\+\([eE][-+]\?\d\+\)\?\>"
syn match LlFloat "\<-\?\d\+[eE][-+]\?\d\+\>"

" Strings
syn region LlString start='"' skip='\\\\\|\\"' end='"'

" Comments — ; to end of line, #! shebang; with TODO/FIXME highlighting inside
syn match LlCommentTodo /\<\(TODO\|FIXME\|NOTE\|XXX\|HACK\)\>/ contained
syn match LlComment ";.*$" contains=LlCommentTodo
syn match LlComment "^#!.*$" contains=LlCommentTodo

" Unmatched close paren is an error
syn match LlParenError ")"

syn sync lines=100

hi def link LlAtomMark       Delimiter
hi def link LlSigil          Special
hi def link LlAtom           Identifier
hi def link LlComment        Comment
hi def link LlCommentTodo    Todo
hi def link LlForm           Statement
hi def link LlFunc           Function
hi def link LlMacro          Operator
hi def link LlConst          Constant
hi def link LlQuasi          Special
hi def link LlNumber         Number
hi def link LlFloat          Float
hi def link LlParenError     Error
hi def link LlString         String
hi def link LlBool           Boolean

" Rainbow parentheses — each nesting level gets its own colour.
" Each region contains the cluster plus the next level; level 9 wraps to 0.
" Toggle with \r (or :LlRainbow) — controlled by g:ll_rainbow (default: 1).
syn cluster LlListCluster contains=LlAtom,LlAtomMark,LlConst,LlComment,LlCommentTodo,LlFunc,LlNumber,LlFloat,LlSymbol,LlForm,LlString,LlMacro,LlQuasi,LlSigil

if !exists("g:ll_rainbow")
  let g:ll_rainbow = 0
endif

if g:ll_rainbow
  syn region LlList0 matchgroup=LlLevel0 start="(" end=")" contains=@LlListCluster,LlList1
  syn region LlList1 matchgroup=LlLevel1 start="(" end=")" contains=@LlListCluster,LlList2
  syn region LlList2 matchgroup=LlLevel2 start="(" end=")" contains=@LlListCluster,LlList3
  syn region LlList3 matchgroup=LlLevel3 start="(" end=")" contains=@LlListCluster,LlList4
  syn region LlList4 matchgroup=LlLevel4 start="(" end=")" contains=@LlListCluster,LlList5
  syn region LlList5 matchgroup=LlLevel5 start="(" end=")" contains=@LlListCluster,LlList6
  syn region LlList6 matchgroup=LlLevel6 start="(" end=")" contains=@LlListCluster,LlList7
  syn region LlList7 matchgroup=LlLevel7 start="(" end=")" contains=@LlListCluster,LlList8
  syn region LlList8 matchgroup=LlLevel8 start="(" end=")" contains=@LlListCluster,LlList9
  syn region LlList9 matchgroup=LlLevel9 start="(" end=")" contains=@LlListCluster,LlList0

  if &background ==# "dark"
    hi def LlLevel0 ctermfg=red         guifg=red1
    hi def LlLevel1 ctermfg=yellow      guifg=orange1
    hi def LlLevel2 ctermfg=green       guifg=yellow1
    hi def LlLevel3 ctermfg=cyan        guifg=greenyellow
    hi def LlLevel4 ctermfg=magenta     guifg=green1
    hi def LlLevel5 ctermfg=red         guifg=springgreen1
    hi def LlLevel6 ctermfg=yellow      guifg=cyan1
    hi def LlLevel7 ctermfg=green       guifg=slateblue1
    hi def LlLevel8 ctermfg=cyan        guifg=magenta1
    hi def LlLevel9 ctermfg=magenta     guifg=purple1
  else
    hi def LlLevel0 ctermfg=red         guifg=red3
    hi def LlLevel1 ctermfg=darkyellow  guifg=orangered3
    hi def LlLevel2 ctermfg=darkgreen   guifg=orange2
    hi def LlLevel3 ctermfg=blue        guifg=yellow3
    hi def LlLevel4 ctermfg=darkmagenta guifg=olivedrab4
    hi def LlLevel5 ctermfg=red         guifg=green4
    hi def LlLevel6 ctermfg=darkyellow  guifg=paleturquoise3
    hi def LlLevel7 ctermfg=darkgreen   guifg=deepskyblue4
    hi def LlLevel8 ctermfg=blue        guifg=darkslateblue
    hi def LlLevel9 ctermfg=darkmagenta guifg=darkviolet
  endif
else
  syn region LlList matchgroup=LlParen start="(" end=")" contains=@LlListCluster,LlList
  hi def link LlParen Delimiter
endif

let b:current_syntax = "ll"
