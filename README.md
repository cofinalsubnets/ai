# g

every `g` value is a total monadic function `g -> g`.
1 is the identity function, 0 is the constant function of 1,
numbers act on functions by iteration (church numerals),
and a list represents an exponential tower.
- `(0 x) = 1`
- `(1 x) = (x) = x`
- `(f x y) = ((f x) y)`
- `(2 f x) = (f (f x))`
- `(2 3 4) = 262144`
- `(* i pi e) = -1`
the language is built around three special forms plus reader sigils.
the special forms are:
- `\` lam
- `?` cond
- `:` let
the reader sigils are:
- `#` pin (saturating projection to non-negative fixnum, length operator on list/string/map)
- `'` quote (literally the zero-variable lambda case)
- `!` bang (`!!#` defines truth values)
- `.` dot (printing identity)
- `~` wave (complex constructor / conjugate)
- `$` nom (gensym constructor)
- `@` tup (array constructor)
- `%` map (map constructor)

quasiquotation — `` ` `` quasiquote, `,` unquote, `,@` splice — are reader sigils, not monadic operators.

## code examples

euler's identity
```
(= -1 (* i pi e))
```

hello world

```
."hello world\n"
```

fizzbuzz

```
(100
 (\ n (: f (? (mod n 3) "" "fizz")
         b (? (mod n 5) "" "buzz")
         _ .(? (| #f #b) (+ f b) n)
         _ ."\n"
       (+ 1 n)))
 1)
```

