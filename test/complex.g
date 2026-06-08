; step 7: complex arithmetic.
; - a complex is a rank-0 scalar (Cp), the widest numeric tier: complex >
;   float > int/bignum. (C re im) builds one; `i` = (C 0 1) is the unit.
; - + - * / promote a real operand to (r, 0); % is undefined (-> nil).
; - sticky: never demotes to a real, even when im is 0 (eql-distinct keys).
; - ordered: < <= > >= sort a complex lexicographically by (re, im); a real r is
;   (r, 0). `=` bridges to reals. (A rank-N c array operand stays elementwise.)
; - accessors re / im / conj / abs / arg; abs is type-aware.

(: (close? a b eps) (< (- (? (< a b) (- b a) (- a b)) 0) eps)
   (close a b)       (close? a b 1e-12)
   (cclose z w)      (? (close (re z) (re w)) (close (im z) (im w)) 0)
   B100 (** 2 100))

(assert
 ; --- printer: (C re im) constructor form, reads back by re-evaluation ---
 (= "(C 0.0 1.0)" (inspect i))
 (= "(C 2.0 3.0)" (inspect (C 2 3)))
 (= "(C 2.0 -3.0)" (inspect (C 2 -3)))
 (= "(C -1.0 -2.0)" (inspect (C -1 -2)))

 ; --- the defining identity, and that `=` bridges complex to a real ---
 (= (* i i) -1)                           ; i^2 = -1+0i, equal to the real -1
 (= (C 2 0) 2)                          ; cross-real equality (im 0)
 (= (C 2 0) 2.0)
 (= (+ 2 (* 3 i)) (C 2 3))              ; 2+3i built through the arith lanes

 ; --- sticky: a real-valued complex stays complex (distinct from the real) ---
 (Cp (C 2 0))
 (Cp i)
 (nilp (Cp 5))
 (nilp (Cp 5.0))

 ; --- componentwise add / sub; Gaussian mul; div by conjugate ---
 (= (+ (C 1 2) (C 3 4)) (C 4 6))
 (= (- (C 1 2) (C 3 4)) (C -2 -2))
 (= (* (C 1 2) (C 3 4)) (C -5 10))
 (cclose (/ (C 1 2) (C 3 4)) (C 0.44 0.08))
 (= (* (C 0 2) i) -2)                   ; 2i * i = -2 (real), via cross-real =

 ; --- accessors ---
 (= 2.0 (re (C 2 3)))
 (= 3.0 (im (C 2 3)))
 (= (conj (C 2 3)) (C 2 -3))
 (= 7 (re 7))                              ; re of a real is itself
 (nilp (im 7))                             ; im of a real is 0
 (= 5 (conj 5))                            ; conj of a real is itself

 ; --- abs: type-aware. complex -> float magnitude; real stays in its tier ---
 (= 5.0 (abs (C 3 4)))
 (= 13.0 (abs (C -5 12)))
 (= 5 (abs -5))   (fixp (abs -5))          ; fixnum abs stays a fixnum
 (= 5 (abs 5))
 (= 5.5 (abs -5.5))                        ; float abs stays a float
 (= B100 (abs (- 0 B100)))                 ; bignum abs flips the sign, stays a bignum
 (= B100 (abs B100))

 ; --- arg: phase. complex via atan2; real -> 0 (>=0) or pi (<0) ---
 (close (/ pi 2) (arg i))
 (close 0 (arg (C 1 0)))
 (close pi (arg -1))
 (close 0 (arg 5))

 ; --- ordered lexicographically by (re, im); a real r is (r, 0). i = (0,1) and
 ;     1 = (1,0): re 0 < 1, so i < 1; equal re falls back to im ---
 (< i 1)   !(> i 1)   (<= i 1)   !(>= i 1)
 !(< 1 i)   (< (C 1 1) (C 2 2))   (<= (C 1 1) (C 2 2))
 (< (C 2 1) (C 2 5))   !(< (C 2 5) (C 2 1))

 ; --- % is undefined on complex; sin/sqrt/atan2 stay real-domain (deferred) ---
 (nilp (mod i 2))
 (nilp (sin i))   (nilp (sqrt i))   (nilp (atan2 i 1))
 ; pow IS defined on complex: w^z = exp(z Log w). i^2 = -1, i^i = e^(-pi/2) (real)
 (close -1 (re (pow i 2)))   (close 0 (im (pow i 2)))
 (close 0.20787957635076193 (re (pow i i)))   (close 0 (im (pow i i)))

 ; --- truthiness: a complex zero is falsy, any nonzero part is truthy ---
 (nilp (C 0 0))
 (nilp (C 0 0.0))
 (? i -1 0)                                ; i is truthy
 (? (C 0 1) -1 0)
 (nilp (nilp i))

 ; --- complex meets bignum: the bignum narrows to double (floating domain) ---
 (Cp (+ i B100))
 (= 1.0 (im (+ i B100)))                   ; imaginary part untouched
 (< 1e29 (re (+ i B100)))                  ; real part ~ 2^100

 ; --- complex as hash keys: eql-distinct from the equal real (sticky) ---
 (= 'hit (get 'miss (C 2 0) (put (C 2 0) 'hit (hashn 0))))
 (= 'miss (get 'miss 2 (put (C 2 0) 'hit (hashn 0))))   ; 2 and 2+0i are different keys
 (= 'iv (get 'miss i (put i 'iv (hashn 0)))))

; --- step 7b: full-rank complex arrays (packed (re,im) g_C tuples) -----------
; a complex value packs two floats per element into a `c` array (type code c = 2,
; the tier between f64 and o). arr/arrl/array/@ all build them (a-type infers c);
; `get` returns a (C re im) box; + - * / broadcast in the complex domain; `=` ->
; a 0/1 mask, the orderings -> nil; asum/aprod fold complex; aall/aany lift the
; 0+0i-is-falsy rule. (body-less `:` -> ca-* leak to global, reused in roundtrip.g)
(: ca-z (arr c '(3))                             ; zero-filled: three 0+0i
   ca-v (arrl c '(2) (L (C 1 2) (C 3 4)))        ; explicit packed pair
   ca-a (array 3 (C 1 1) (C 2 2) (C 3 3))        ; `array` infers c from its args
   ca-r @((C 1 0) (C 0 1))                       ; `@` reader infers c too
   ca-m (array '(2 2) (C 1 0) (C 0 1) (C 2 0) (C 0 2)))  ; rank-2 complex

(assert
 ; --- construction / type / shape ---
 (= 2 c)   (= c (atype ca-v))   (= c (atype ca-z))   (= c (atype ca-a))
 (= c (atype ca-r))   (= c (atype ca-m))
 (= 1 (arank ca-v))   (= 2 (alen ca-v))
 (= 2 (arank ca-m))   (= 4 (alen ca-m))

 ; --- get returns a complex box; rank-N indexing; zero element ---
 (= (C 1 2) (get 0 0 ca-v))   (= (C 3 4) (get 0 1 ca-v))   (Cp (get 0 0 ca-v))
 (= (C 0 2) (get 0 (L 1 1) ca-m))                ; row-major (1,1)
 (= (C 0 0) (get 0 0 ca-z))   (= (C 2 2) (get 0 1 ca-a))

 ; --- elementwise broadcast: array (op) array ---
 (= (C 2 4) (get 0 0 (+ ca-v ca-v)))             ; (1+2i)+(1+2i) elementwise
 (aall (= ca-v (+ ca-v (arr c '(2)))))           ; + the zero array is identity
 (= (C -5 10) (get 0 1 (* (arrl c '(2) (L (C 1 1) (C 1 2))) ca-v)))  ; (1+2i)(3+4i)
 (= (C 1 2) (get 0 0 (/ (* ca-v ca-v) ca-v)))    ; (z*z)/z = z

 ; --- scalar broadcast: complex scalar (op) array, both orders ---
 (= (C 11 2) (get 0 0 (+ (C 10 0) ca-v)))
 (= (C 13 4) (get 0 1 (+ ca-v (C 10 0))))
 (= (C 2 4) (get 0 0 (* (C 2 0) ca-v)))          ; scale by 2
 (= (C 0 1) (get 0 0 (* i ca-r)))                ; i*(1+0i) = i

 ; --- real array meets complex: the real promotes to (v, 0) ---
 (= (C 11 2) (get 0 0 (+ @(10 20) ca-v)))        ; i64 @(10 20) lifts to (10,0)/(20,0)
 (= (C 23 4) (get 0 1 (+ ca-v @(10 20))))

 ; --- `=` over complex arrays -> a 0/1 mask; orderings/% -> nil ---
 (= 1 (get 0 0 (= ca-v ca-v)))
 (= 0 (get 0 0 (= ca-v (arrl c '(2) (L (C 9 9) (C 3 4))))))
 (aall (= ca-v ca-v))
 (nilp (< ca-v ca-v))   (nilp (> ca-v ca-v))   (nilp (mod ca-v ca-v))

 ; --- reductions: complex sum / product; max/min unordered -> nil ---
 (= (C 4 6) (asum ca-v))                         ; (1+2i)+(3+4i)
 (= (C -5 10) (aprod ca-v))                      ; (1+2i)*(3+4i)
 (= (C 6 6) (asum ca-a))   (= (C 0 0) (asum ca-z))
 (nilp (amax ca-v))   (nilp (amin ca-v))

 ; --- aall/aany lift the 0+0i-is-falsy rule ---
 (aall ca-v)
 (nilp (aall (arrl c '(2) (L (C 0 0) (C 1 1)))))   ; a 0+0i element fails aall
 (len (arrl c '(2) (L (C 0 0) (C 1 1))))          ; one nonzero satisfies aany
 (nilp (len ca-z))

 ; --- abs of a complex array = the flat L2 norm over every (re, im) ---
 (= 5.0 (abs (arrl c '(1) (L (C 3 4)))))          ; |3+4i| = 5
 (close (sqrt 30) (abs ca-v))                     ; sqrt(1+4+9+16)

 ; --- len / nilp: the invariant (nilp x) == (= 0 (len x)) holds here too ---
 (= 0 (len ca-z))   (nilp ca-z)
 (not (nilp ca-v))   (= 6 (len ca-v))             ; ceil(sqrt 30) = 6
 (= (? (nilp ca-v) 1 0) (? (= 0 (len ca-v)) 1 0))
 (= (? (nilp ca-z) 1 0) (? (= 0 (len ca-z)) 1 0))

 ; --- printer: rank-1 terse @((C…)…); rank>=2 (array '(…) (C…)…) ---
 (= "@((C 1.0 2.0) (C 3.0 4.0))" (inspect ca-v))
 (= "(array '(2 2) (C 1.0 0.0) (C 0.0 1.0) (C 2.0 0.0) (C 0.0 2.0))" (inspect ca-m)))
