; step 5a: typed multi-rank arrays.
; - (arr type shape) zero-fills; (arrl type shape vals) fills row-major
; - get: fixnum index (rank 1), shape-list index (rank N), oob -> default
; - arank / alen / ashape / atype accessors
; - elementwise + - * / over arrays + scalar broadcast + numpy broadcasting
; - mixed element-type promotes to the widest type
; - < <= > >= = elementwise -> 0/1 bool array
; - reductions asum aprod amax amin aall aany; identity on scalars
; - vector falsiness: a tuple is false iff every element is 0
; - elementwise transcendentals (sqrt) over an array
; - print round-trip; non-conforming / non-numeric -> nil

(assert
 ; --- constructor + accessors ---
 (= 2 (arank (arr z '(2 3))))
 (= 0 (arank (arr z 0)))            ; empty shape (nil) -> rank-0 scalar
 (= 6 (alen (arr z '(2 3))))
 (= 1 (alen (arr r 0)))             ; rank-0 has one element
 (= z (atype (arr z '(2 3))))
 (= r (atype (arr r '(4))))
 (= '(2 3) (ashape (arr z '(2 3))))
 (= 0 (ashape (arr z 0)))           ; rank-0 shape is the empty list (nil)
 (nilp (arank 5))                     ; non-tuple -> nil
 (nilp (atype "x"))

 ; --- get: rank-1 fixnum index ---
 (= 10 (peek (arrl z '(3) '(10 20 30)) 0 -1))
 (= 20 (peek (arrl z '(3) '(10 20 30)) 1 -1))
 (= 30 (peek (arrl z '(3) '(10 20 30)) 2 -1))
 (= -1 (peek (arrl z '(3) '(10 20 30)) 3 -1))   ; out of bounds -> default
 (= -1 (peek (arrl z '(3) '(10 20 30)) -1 -1))  ; negative -> default

 ; --- get: rank-N shape-list index, row-major ---
 (= 1 (peek (arrl z '(2 2) '(1 2 3 4)) '(0 0) -1))
 (= 2 (peek (arrl z '(2 2) '(1 2 3 4)) '(0 1) -1))
 (= 3 (peek (arrl z '(2 2) '(1 2 3 4)) '(1 0) -1))
 (= 4 (peek (arrl z '(2 2) '(1 2 3 4)) '(1 1) -1))
 (= -1 (peek (arrl z '(2 2) '(1 2 3 4)) '(2 0) -1))  ; oob -> default
 (= -1 (peek (arr z '(2 2)) 0 -1))                   ; wrong-rank key -> default
 (= -1 (peek (arr z '(2 2)) '(0) -1))                ; too-few indices -> default

 ; --- rank-0 deref: empty/nil key yields the lone scalar ---
 (= 2.5 (peek 2.5 0 -9))

 ; --- float element read boxes an r ---
 (= 1.5 (peek (arrl r '(2) '(1.5 2.5)) 0 -1))
 (flop (peek (arrl r '(2) '(1.5 2.5)) 0 -1))

 ; --- scalar broadcast: array (op) scalar ---
 (aall (= (arrl z '(3) '(11 21 31)) (+ (arrl z '(3) '(10 20 30)) 1)))
 (aall (= (arrl z '(3) '(9 19 29)) (- (arrl z '(3) '(10 20 30)) 1)))
 (aall (= (arrl z '(2) '(4 6)) (* (arrl z '(2) '(2 3)) 2)))
 (aall (= (arrl z '(2) '(3 5)) (// (arrl z '(2) '(7 11)) 2)))   ; `//` floor division, stays z
 (= r (atype (/ (arrl z '(2) '(7 11)) 2)))                     ; `/` promotes (7/2 inexact) -> r
 (aall (= (arrl r '(2) '(3.5 5.5)) (/ (arrl z '(2) '(7 11)) 2)))
 (aall (= (arrl z '(2) '(4 6)) (/ (arrl z '(2) '(8 12)) 2)))   ; `/` stays z when every element divides evenly
 (aall (= (arrl z '(2) '(1 1)) (mod (arrl z '(2) '(7 11)) 2)))
 (aall (= (arrl z '(3) '(2 4 6)) (+ 1 (arrl z '(3) '(1 3 5)))))  ; scalar on the left

 ; --- array (op) array, same shape ---
 (aall (= (arrl z '(3) '(11 22 33))
          (+ (arrl z '(3) '(10 20 30)) (arrl z '(3) '(1 2 3)))))
 (aall (= (arrl z '(3) '(9 18 27))
          (- (arrl z '(3) '(10 20 30)) (arrl z '(3) '(1 2 3)))))

 ; --- numpy broadcasting: outer sum of a column and a row ---
 (aall (= (arrl z '(3 3) '(11 21 31 12 22 32 13 23 33))
          (+ (arrl z '(3 1) '(1 2 3)) (arrl z '(1 3) '(10 20 30)))))
 ; size-1 axis stretches
 (aall (= (arrl z '(2 2) '(11 21 12 22))
          (+ (arrl z '(2 2) '(1 1 2 2)) (arrl z '(1 2) '(10 20)))))

 ; --- mixed element-type promotes to the widest ---
 (= r (atype (+ (arr z '(2)) 1.5)))            ; z array + r scalar -> r
 (aall (= (arrl r '(2) '(1.5 1.5)) (+ (arr z '(2)) 1.5)))
 (= z (atype (+ (arr z '(2)) (arr z '(2)))))  ; z + z -> z
 (= z (atype (+ (arr z '(2)) 1)))                ; scalar int never widens the array

 ; --- comparison -> 0/1 bool array ---
 (aall (< (arrl z '(3) '(1 2 3)) 10))
 !(aall (< (arrl z '(3) '(1 2 30)) 10))
 (sat (< (arrl z '(3) '(1 20 30)) 10))
 !(sat (< (arrl z '(3) '(10 20 30)) 5))
 (aall (= (arrl z '(3) '(1 0 1)) (< (arrl z '(3) '(1 5 2)) 3)))
 (= z (atype (< (arr z '(3)) 1)))               ; bool array is z
 ; whole-array equality is (aall (= a b))
 (aall (= (arrl z '(2) '(5 6)) (arrl z '(2) '(5 6))))
 !(aall (= (arrl z '(2) '(5 6)) (arrl z '(2) '(5 7))))

 ; --- reductions ---
 (= 60 (asum (arrl z '(3) '(10 20 30))))
 (= 6000 (aprod (arrl z '(3) '(10 20 30))))
 (= 30 (amax (arrl z '(3) '(10 30 20))))
 (= 10 (amin (arrl z '(3) '(20 10 30))))
 (= 6.0 (asum (arrl r '(3) '(1.0 2.0 3.0))))
 (= 21 (asum (arrl z '(2 3) '(1 2 3 4 5 6))))    ; reduces over all axes
 (aall (arrl z '(3) '(1 2 3)))                   ; no zero element
 !(aall (arrl z '(3) '(1 0 3)))               ; a zero element
 (sat (arrl z '(3) '(0 0 3)))
 !(sat (arr z '(3)))                         ; all zero

 ; --- reductions are the identity on a scalar (rank-agnostic idiom) ---
 (= 5 (asum 5))
 (= 5 (amax 5))
 (= 1 (aall 1))
 (= 0 (aall 0))
 (aall (< 1 2))                                    ; scalar: (< 1 2) = 1, (aall 1) = 1
 !(aall (< 2 1))
 (aall (< (arrl z '(2) '(1 2)) (arrl z '(2) '(3 4))))  ; array: same expression

 ; --- truthiness is zero-magnitude (L2 norm): a value is false iff |x| == 0 ---
 (nilp (arr z '(3)))                  ; zero array -> false
 (nilp (arr r '(2 2)))                ; zero float array -> false
 (nilp (arr z '(0)))                  ; empty array -> vacuously false
 (nilp 0.0)                             ; boxed 0.0 -> false (was a truthy wart)
 !(nilp 2.5)                         ; positive float -> true
 (nilp -5)                           ; a negative real is now FALSE (<= 0)
 !(nilp (+ (arr z '(2)) 1))        ; nonzero array -> true
 !(nilp @(-3 -4))                    ; a NEGATIVE array stays true (norm, sign squares away)
 (= 1 (? (arr z '(3)) 0 1))         ; zero array takes the false arm
 (= 0 (? (+ (arr z '(3)) 1) 0 1))    ; nonzero array takes the true arm
 ; a single non-zero component makes the norm non-zero (truthy), per the tower:
 !(nilp @(0 0 5))                    ; one non-zero element -> true
 (nilp @(0.0 0.0))                      ; all-zero float tuple -> false
 (nilp ~(0 0))                         ; complex 0+0i (|z|=0) -> false
 !(nilp ~(0 1))                     ; 0+1i (|z|=1) -> true
 !(nilp i)                           ; the imaginary unit is truthy

 ; --- elementwise transcendentals over an array ---
 (aall (= (arrl r '(2) '(2.0 3.0)) ((/ 1 2) (arrl r '(2) '(4.0 9.0)))))
 (= r (atype ((/ 1 2) (arr z '(3)))))  ; result is a float array

 ; --- print as constructor forms ---
 ; rank-1 numeric -> the @(…) sugar (@ reader splices into (tuple …)); rank>=2 ->
 ; an explicit (arrl <type> '(shape) '(vals)) call
 (= "@(10 20 30)" (show (arrl z '(3) '(10 20 30))))
 (= "(arrl z '(2 2) '(1 2 3 4))" (show (arrl z '(2 2) '(1 2 3 4))))
 (= "@(1.5 2.5)" (show (arrl r '(2) '(1.5 2.5))))
 (= "@(1 2 3)" (show (arrl z '(3) '(1 2 3))))   ; z aliases the word-int kind -> terse @
 ; @(…) reads back to an equal array; the explicit form is a plain constructor call
 (aall (= (arrl z '(3) '(10 20 30)) @(10 20 30)))
 (aall (= (arrl r '(2) '(1.5 2.5)) @(1.5 2.5)))
 (aall (= (arrl z '(2 2) '(1 2 3 4)) (arrl z '(2 2) '(1 2 3 4))))
 ; the printed form reads back to an equal array
 (aall (= (arrl z '(3) '(10 20 30)) (tuple 10 20 30)))
 (aall (= (arrl z '(2 2) '(1 2 3 4)) (arrl z '(2 2) '(1 2 3 4))))
 (aall (= (arrl r '(2) '(1.5 2.5)) (tuple 1.5 2.5)))

 ; --- non-conforming / non-numeric -> nil ---
 (nilp (+ (arr z '(3)) (arr z '(4))))   ; shapes [3] and [4] don't conform
 (nilp (+ (arr z '(3)) "x"))              ; non-numeric operand
 (nilp (arr z '(3)))                      ; (sanity) zero array is falsy
 (nilp (arr 99 '(3))))                      ; bad type code -> nil
