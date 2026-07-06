; crew/cc/gen.l -- the code generator (rung 3 stage 3). AST -> (1 ir-forms) |
; (). holo's neutral IR, chibicc-plain: every expression computes into r0 and
; now CARRIES ITS TYPE -- cgexpr answers (type forms) so pointer arithmetic
; scales, dereferences load by pointee width, and arrays decay to addresses.
; types: 'char 'short 'int 'long | ('ptr t) | ('arr t n). the ALU stays
; 64-bit (signed overflow is UB); widths bite only at memory and casts.
; lvalues have their own door (clval: the ADDRESS in r0 + the pointee type),
; so x, *p, and a[i] assign through one path. locals off the r4 frame;
; globals and string literals are LABELED RAW DATA after the code, reached
; by holo's (la) -- the one RWX segment carries text and data both until
; the .o seam (the doc). args ride the SysV registers r6 r5 r2 r1 r7 r8,
; at most six; call args evaluate left to right. fenced and refused, not
; fudged: ptr+ptr, deref of a non-pointer, assigning to an array, global
; initializers past a constant, string-initialized globals.
(:
   ; the gen state g (a tablet): 'n the label counter, 'off the frame's
   ; high-water offset, 'brk/'cnt the loop label stacks, 'glob the global
   ; table (name -> (label ty init)), 'globs the emission order, 'strs the
   ; string table ((label . text)..). env: ((name off ty)..) frame locals.
   (nlab g pfx) (: k (peep g 'n 0) _ (pin g 'n (+ k 1)) (intern (+ pfx (show k))))
   argregs '(r6 r5 r2 r1 r7 r8)
   (nthr l i) (? (< i 1) (cap l) (nthr (cup l) (- i 1)))
   (bad? x) (id? x 'bad)
   ; -- the type floor --
   (ptr? ty) (&& (two? ty) (= (cap ty) 'ptr))
   (arr? ty) (&& (two? ty) (= (cap ty) 'arr))
   (tsz ty) (? (ptr? ty) 8
               (arr? ty) (* (cauup ty) (tsz (caup ty)))
               (= ty 'char) 1 (= ty 'short) 2 (= ty 'int) 4 8)
   (lg2 n) (? (= n 1) 0 (= n 2) 1 (= n 4) 2 3)
   (ldop ty) (? (= ty 'char) 'ld1 (= ty 'short) 'ld2 (= ty 'int) 'ld4 'ld)
   (stop ty) (? (= ty 'char) 'st1 (= ty 'short) 'st2 (= ty 'int) 'st4 'st)
   (cvt ty r) (? (= ty 'char) (L (L 'sx1 r)) (= ty 'short) (L (L 'sx2 r))
                 (= ty 'int) (L (L 'sx4 r)) ())
   ; 8 little-endian bytes of a constant (the global initializer image)
   (le8s v) (: (go i acc) (? (< 7 i) (rev acc)
                             (go (+ i 1) (link (& (>> v (* 8 i)) 255) acc)))
              (go 0 ()))
   (zeros n) (? (< n 1) () (link 0 (zeros (- n 1))))

   ; -- the environments: locals shadow globals --
   (vent g env name)                                ; -> ('loc off ty) | ('glo lbl ty) | 'bad
    (: e (assoc name env)
       (? (two? e) (L 'loc (caup e) (cauup e))
          (: ge (peep (g 'glob) name 0)
             (? (two? ge) (L 'glo (cap ge) (caup ge)) 'bad))))

   ; -- lvalues: the ADDRESS lands in r0; answers (pointee-ty forms) | 'bad --
   (clval g env e)
    (: k (cap e)
       (? (= k 'var)
           (: en (vent g env (caup e))
              (? (bad? en) 'bad
                 (= (cap en) 'loc) (L (cauup en) (L (L 'lea 'r0 'r4 (caup en))))
                 (L (cauup en) (L (L 'la 'r0 (caup en))))))
          (= k 'deref)
           (: r (cgexpr g env (caup e))
              (? (bad? r) 'bad
                 (! (ptr? (cap r))) 'bad
                 (L (caup (cap r)) (caup r))))
          'bad))

   ; -- expressions: answers (type forms) | 'bad, the value in r0 --
   (cgexpr g env e)
    (: k (cap e)
       (? (= k 'num) (L 'long (L (L 'li 'r0 (caup e))))
          (= k 'str)
           (: lbl (nlab g ".S")
              _ (pin g 'strs (link (L lbl (caup e)) (g 'strs)))
              (L (L 'ptr 'char) (L (L 'la 'r0 lbl))))
          (= k 'var)
           (: en (vent g env (caup e))
              (? (bad? en) 'bad
                 (: ty (cauup en)
                    (? (arr? ty)                     ; arrays decay to their address
                       (? (= (cap en) 'loc)
                          (L (L 'ptr (caup ty)) (L (L 'lea 'r0 'r4 (caup en))))
                          (L (L 'ptr (caup ty)) (L (L 'la 'r0 (caup en)))))
                       (? (= (cap en) 'loc)
                          (L ty (L (L (ldop ty) 'r0 'r4 (caup en))))
                          (L ty (L (L 'la 'r1 (caup en)) (L (ldop ty) 'r0 'r1 0))))))))
          (= k 'addr)
           (: r (clval g env (caup e))
              (? (bad? r) 'bad (L (L 'ptr (cap r)) (caup r))))
          (= k 'deref)
           (: r (clval g env e)                     ; clval already walked the pointer
              (? (bad? r) 'bad
                 (: ty (cap r)
                    (? (arr? ty) (L (L 'ptr (caup ty)) (caup r))   ; pointee array: decay again
                       (L ty (cat (caup r) (L (L (ldop ty) 'r0 'r0 0))))))))
          (= k 'asn)
           (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (arr? (cap lv)) 'bad                ; an array is not assignable
                 (: r (cgexpr g env (cauup e))
                    (? (bad? r) 'bad
                       (: ty (cap lv)
                          (L ty (cat (caup lv)
                                 (cat (L (L 'push 'r0))
                                  (cat (caup r)
                                   (cat (L (L 'pop 'r1))
                                    (cat (cvt ty 'r0)
                                         (L (L (stop ty) 'r1 0 'r0)))))))))))))
          (= k 'post)
           (: lv (clval g env (caup e))
              (? (bad? lv) 'bad
                 (: ty (cap lv)
                    stp (? (ptr? ty) (tsz (caup ty)) 1)
                    (? (arr? ty) 'bad
                       (L ty (cat (caup lv)
                              (L (L 'mov 'r2 'r0)
                                 (L (ldop ty) 'r0 'r2 0)
                                 (L 'add 'r1 'r0 (* stp (cauup e)))
                                 (L (stop ty) 'r2 0 'r1))))))))
          (= k 'cast)
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (L (caup e) (cat (caup r) (cvt (caup e) 'r0)))))
          (= k 'un)
           (: r (cgexpr g env (cauup e))
              (? (bad? r) 'bad
                 (L 'long
                    (cat (caup r)
                         (? (= (caup e) 'neg) (L (L 'neg 'r0))
                            (= (caup e) 'bnot) (L (L 'not 'r0))
                            (L (L 'cmp 'r0 0) (L 'set 'eq 'r0)))))))
          (= k 'comma)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              (? (|| (bad? a) (bad? b)) 'bad
                 (L (cap b) (cat (caup a) (caup b)))))
          (= k 'land)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              lf (nlab g ".f") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (L 'long
                    (cat (caup a) (cat (L (L 'cmp 'r0 0) (L 'br 'eq lf))
                     (cat (caup b) (L (L 'cmp 'r0 0) (L 'br 'eq lf)
                                      (L 'li 'r0 1) (L 'jmp ld)
                                      (L 'label lf) (L 'li 'r0 0) (L 'label ld))))))))
          (= k 'lor)
           (: a (cgexpr g env (caup e)) b (cgexpr g env (cauup e))
              lt (nlab g ".t") ld (nlab g ".d")
              (? (|| (bad? a) (bad? b)) 'bad
                 (L 'long
                    (cat (caup a) (cat (L (L 'cmp 'r0 0) (L 'br 'ne lt))
                     (cat (caup b) (L (L 'cmp 'r0 0) (L 'br 'ne lt)
                                      (L 'li 'r0 0) (L 'jmp ld)
                                      (L 'label lt) (L 'li 'r0 1) (L 'label ld))))))))
          (= k 'cond)
           (: c (cgexpr g env (caup e))
              t (cgexpr g env (cauup e))
              el (cgexpr g env (caup (cuup e)))
              le (nlab g ".e") ld (nlab g ".d")
              (? (|| (bad? c) (|| (bad? t) (bad? el))) 'bad
                 (L (cap t)
                    (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                     (cat (caup t) (cat (L (L 'jmp ld) (L 'label le))
                      (cat (caup el) (L (L 'label ld))))))))))
          (= k 'call)
           (: args (cauup e)
              n (tally args)
              (? (< 6 n) 'bad
                 (: (pushes as acc)
                     (? (! (two? as)) acc
                        (: r (cgexpr g env (cap as))
                           (? (bad? r) 'bad
                              (: r2 (pushes (cup as) (cat acc (cat (caup r) (L (L 'push 'r0)))))
                                 (? (bad? r2) 'bad r2)))))
                    up (pushes args ())
                    (pops i acc) (? (< i 0) acc
                                    (pops (- i 1) (cat acc (L (L 'pop (nthr argregs i))))))
                    (? (bad? up) 'bad
                       (L 'long (cat up (cat (pops (- n 1) ())
                                             (L (L 'call (intern (caup e)))))))))))
          (= k 'bin) (cgbin g env e)
          'bad))
   (cgbin g env e)
    (: op (caup e)
       a (cgexpr g env (cauup e))
       b (cgexpr g env (caup (cuup e)))
       rhs (caup (cuup e))
       (? (|| (bad? a) (bad? b)) 'bad
          ; a constant count rides the immediate shift; a variable count
          ; rides shlv/sarv with the count PINNED to r1 (holo's contract)
          (member? op '(shl shr))
           (? (= (cap rhs) 'num)
              (L 'long (cat (caup a) (L (L (? (= op 'shl) 'shl 'sar) 'r0 (caup rhs)))))
              (L 'long (cat (caup a)
                        (cat (L (L 'push 'r0))
                         (cat (caup b) (L (L 'mov 'r1 'r0) (L 'pop 'r0)
                                          (L (? (= op 'shl) 'shlv 'sarv) 'r0 'r1)))))))
          (: ta (cap a) tb (cap b)
             pa (ptr? ta) pb (ptr? tb)
             ; left lands in r1, right in r0; scale the int side of ptr math
             mid (cat (caup a) (cat (L (L 'push 'r0)) (cat (caup b) (L (L 'pop 'r1)))))
             back (L (L 'mov 'r0 'r1))
             (? (= op '+)
                 (? (&& pa pb) 'bad
                    pa (L ta (cat mid (cat (? (< 1 (tsz (caup ta)))
                                             (L (L 'imul 'r0 'r0 (tsz (caup ta)))) ())
                                      (cat (L (L 'add 'r1 'r1 'r0)) back))))
                    pb (L tb (cat mid (cat (? (< 1 (tsz (caup tb)))
                                             (L (L 'imul 'r1 'r1 (tsz (caup tb)))) ())
                                      (cat (L (L 'add 'r1 'r1 'r0)) back))))
                    (L 'long (cat mid (cat (L (L 'add 'r1 'r1 'r0)) back))))
                (= op '-)
                 (? (&& pa pb)
                     (? (= (tsz (caup ta)) (tsz (caup tb)))
                        (L 'long (cat mid (cat (L (L 'sub 'r1 'r1 'r0))
                                          (cat back (? (< 1 (tsz (caup ta)))
                                                       (L (L 'sar 'r0 (lg2 (tsz (caup ta)))))
                                                       ())))))
                        'bad)
                    pa (L ta (cat mid (cat (? (< 1 (tsz (caup ta)))
                                             (L (L 'imul 'r0 'r0 (tsz (caup ta)))) ())
                                      (cat (L (L 'sub 'r1 'r1 'r0)) back))))
                    pb 'bad
                    (L 'long (cat mid (cat (L (L 'sub 'r1 'r1 'r0)) back))))
                (: tail (? (= op '*) (L (L 'imul 'r1 'r1 'r0))
                           (= op '/) (L (L 'div 'r1 'r1 'r0))
                           (= op '%) (L (L 'rem 'r1 'r1 'r0 'r3))
                           (= op '&) (L (L 'and 'r1 'r1 'r0))
                           (= op '|) (L (L 'or 'r1 'r1 'r0))
                           (= op '^) (L (L 'xor 'r1 'r1 'r0))
                           'bad)
                   (? (! (bad? tail))
                      (L 'long (cat mid (cat tail back)))
                      (member? op '(eq ne lt le gt ge))
                       (L 'long (cat mid (L (L 'cmp 'r1 'r0) (L 'set op 'r0))))
                      'bad))))))

   epi (L (L 'mov 'sp 'r4) (L 'pop 'r4) (L 'ret))

   ; a declaration list ((name ty init)..): slots by SIZE (rounded to 8),
   ; extends env -> (forms env) | 'bad. array locals take their whole span
   ; and refuse initializers this stage.
   (cgdecl g env pairs)
    (: (one ps env2 acc)
        (? (! (two? ps)) (L acc env2)
           (: p (cap ps)
              ty (caup p)
              span (& (+ (tsz ty) 7) -8)
              off (- 0 (+ (peep g 'off 0) span))
              _ (pin g 'off (+ (peep g 'off 0) span))
              env3 (link (L (cap p) off ty) env2)
              (? (! (two? (cauup p))) (one (cup ps) env3 acc)
                 (arr? ty) 'bad
                 (: r (cgexpr g env3 (cauup p))
                    (? (bad? r) 'bad
                       (one (cup ps) env3
                            (cat acc (cat (caup r)
                                     (cat (cvt ty 'r0)
                                          (L (L (stop ty) 'r4 off 'r0)))))))))))
       (one pairs env ()))

   ; stmt -> forms | 'bad
   (cgstmt g env s)
    (: k (cap s)
       (? (= k 'ret) (: r (cgexpr g env (caup s))
                        (? (bad? r) 'bad (cat (caup r) epi)))
          (= k 'expr) (: r (cgexpr g env (caup s))
                         (? (bad? r) 'bad (caup r)))
          (= k 'nop) ()
          (= k 'blk) (cgitems g env (caup s) ())
          (= k 'if)
           (: c (cgexpr g env (caup s))
              t (cgstmt g env (cauup s))
              le (nlab g ".e")
              (? (|| (bad? c) (bad? t)) 'bad
                 (! (two? (caup (cuup s))))
                  (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le)) (cat t (L (L 'label le)))))
                 (: el (cgstmt g env (caup (cuup s)))
                    ld (nlab g ".d")
                    (? (bad? el) 'bad
                       (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq le))
                        (cat t (cat (L (L 'jmp ld) (L 'label le))
                         (cat el (L (L 'label ld)))))))))))
          (= k 'while)
           (: lc (nlab g ".c") ld (nlab g ".d")
              c (cgexpr g env (caup s))
              _ (pin g 'brk (link ld (g 'brk)))
              _ (pin g 'cnt (link lc (g 'cnt)))
              b (cgstmt g env (cauup s))
              _ (pin g 'brk (cup (g 'brk)))
              _ (pin g 'cnt (cup (g 'cnt)))
              (? (|| (bad? c) (bad? b)) 'bad
                 (cat (L (L 'label lc))
                  (cat (caup c) (cat (L (L 'cmp 'r0 0) (L 'br 'eq ld))
                   (cat b (L (L 'jmp lc) (L 'label ld))))))))
          (= k 'for)
           (: init (caup s) cnd (cauup s) stp (caup (cuup s)) body (cauup (cuup s))
              lc (nlab g ".c") ls (nlab g ".s") ld (nlab g ".d")
              ir (? (! (two? init)) (L () env)
                    (= (cap init) 'decl) (cgdecl g env (caup init))
                    (: r (cgexpr g env (caup init))
                       (? (bad? r) 'bad (L (caup r) env))))
              (? (bad? ir) 'bad
                 (: env2 (caup ir)
                    c (? (two? cnd) (cgexpr g env2 cnd) ())
                    _ (pin g 'brk (link ld (g 'brk)))
                    _ (pin g 'cnt (link ls (g 'cnt)))
                    b (cgstmt g env2 body)
                    _ (pin g 'brk (cup (g 'brk)))
                    _ (pin g 'cnt (cup (g 'cnt)))
                    st2 (? (two? stp) (cgexpr g env2 stp) ())
                    (? (|| (bad? c) (|| (bad? b) (bad? st2))) 'bad
                       (cat (cap ir)
                        (cat (L (L 'label lc))
                         (cat (? (two? cnd) (cat (caup c) (L (L 'cmp 'r0 0) (L 'br 'eq ld))) ())
                          (cat b
                           (cat (L (L 'label ls))
                            (cat (? (two? st2) (caup st2) ())
                                 (L (L 'jmp lc) (L 'label ld))))))))))))
          (= k 'brk) (? (two? (g 'brk)) (L (L 'jmp (cap (g 'brk)))) 'bad)
          (= k 'cont) (? (two? (g 'cnt)) (L (L 'jmp (cap (g 'cnt)))) 'bad)
          'bad))
   (cgitems g env items acc)
    (? (! (two? items)) acc
       (: it (cap items)
          (? (= (cap it) 'decl)
             (: r (cgdecl g env (caup it))
                (? (bad? r) 'bad
                   (cgitems g (caup r) (cup items) (cat acc (cap r)))))
             (: r (cgstmt g env it)
                (? (bad? r) 'bad
                   (cgitems g env (cup items) (cat acc r)))))))

   (cgfn g f)                                       ; ('fn name params ('blk items)) -> forms | 'bad
    (: params (cauup f)
       (? (< 6 (tally params)) 'bad
          (: _ (pin g 'off 0)
             (spill ps i env acc)
              (? (! (two? ps)) (L acc env)
                 (: off (- 0 (+ (peep g 'off 0) 8))
                    _ (pin g 'off (+ (peep g 'off 0) 8))
                    (spill (cup ps) (+ i 1)
                           (link (L (cap (cap ps)) off (caup (cap ps))) env)
                           (cat acc (L (L 'st 'r4 off (nthr argregs i)))))))
             sp0 (spill params 0 () ())
             body (cgitems g (caup sp0) (caup (caup (cuup f))) ())
             (? (bad? body) 'bad
                (: frame (& (+ (peep g 'off 0) 15) -16)
                   (cat (L (L 'label (intern (caup f)))
                           (L 'push 'r4) (L 'mov 'r4 'sp) (L 'sub 'sp 'sp frame))
                    (cat (cap sp0)
                     (cat body (cat (L (L 'li 'r0 0)) epi)))))))))

   ; the data tail: globals in declaration order, then the string table
   (cgdata g)
    (: (globs gs acc)
        (? (! (two? gs)) acc
           (: ge (peep (g 'glob) (cap gs) 0)
              lbl (cap ge) ty (caup ge) init (cauup ge)
              span (& (+ (tsz ty) 7) -8)
              bytes (? (two? init) (le8s (caup init)) (zeros span))
              (globs (cup gs) (cat acc (L (L 'label lbl) (L 'raw bytes))))))
       (strs ss acc)
        (? (! (two? ss)) acc
           (: p (cap ss)
              (bts s i bacc) (? (< i 0) bacc (bts s (- i 1) (link (s i) bacc)))
              t (caup p)
              (strs (cup ss) (cat acc (L (L 'label (cap p))
                                         (L 'raw (cat (bts t (- (tally t) 1) ()) (L 0))))))))
       (cat (globs (rev (g 'globs)) ()) (strs (g 'strs) ())))

   (cgen ast)                                       ; ('prog items) -> (1 forms) | ()
    (: g (: t (tablet 0) _ (pin t 'n 0) _ (pin t 'brk ()) _ (pin t 'cnt ())
            _ (pin t 'glob (tablet 0)) _ (pin t 'globs ()) _ (pin t 'strs ()) t)
       crt0 (L (L 'call 'main) (L 'mov 'r6 'r0) (L 'li 'r0 60) (L 'sys))
       ; pass 1: record the globals (constant or absent initializers only)
       (rec fs)
        (? (! (two? fs)) 1
           (: f (cap fs)
              (? (! (= (cap f) 'gdecl)) (rec (cup fs))
                 (: (one ps)
                     (? (! (two? ps)) (rec (cup fs))
                        (: p (cap ps)
                           init (cauup p)
                           (? (&& (two? init) (! (= (cap init) 'num))) ()
                              (: _ (pin (g 'glob) (cap p) (L (intern (cap p)) (caup p) init))
                                 _ (pin g 'globs (link (cap p) (g 'globs)))
                                 (one (cup ps))))))
                    (one (caup f))))))
       ok (rec (caup ast))
       (gfns fs acc saw)
        (? (! (two? fs))
           (? saw (L 1 (cat crt0 (cat acc (cgdata g)))) ())
           (: f (cap fs)
              (? (member? (cap f) '(proto gdecl)) (gfns (cup fs) acc saw)
                 (: r (cgfn g f)
                    (? (bad? r) ()
                       (gfns (cup fs) (cat acc r)
                             (|| saw (= (caup f) "main"))))))))
       (? ok (gfns (caup ast) () ()) ())))
