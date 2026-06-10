# ll

`ll` is a fusion of lisp, haskell, apl implemented directly on top of C.
every `ll` value is a total monadic function `ll -> ll`.
numbers are finite iterators (church numerals) and lists are exponential towers.
- `0 x = 1`
- `1 x = x`
- `(x) = x`
- `(f x y) = ((f x) y)`
- `(2 f x) = (f (f x))`
- `(2 3 4) = 262144`
- `(* i i) = -1`
- `(log -1) = (* i pi)`
- `((/ 1 2) -1) = i`

ll has three special forms plus reader operators.
the forms are:
- `\` lam (with a single operand, quote)
- `?` cond
- `:` letrec*/sequence

the prefix reader operators aka sigils are
- `.` dot (printing identity function, does what you want on strings)
- `$` sat (aka cash; saturating reduction to fixed width nat, len on collections)
- `!` nil (negation); `!!$` defines the `?` condition
- `'` quote (desugars to monadic lambda)
- `` ` `` quasiquotation with the usual `,` `,@`

plus the data constructors
- `#` hash (hash/box literal)
- `@` at (array literal)
- `~` plex (complex literal/conjugate)

all-punctuation names act as infix operators with flat right-associative
precedence; with no left operand they read as plain symbols, so `(1 + 2)`,
`'+`, and `(+)` all work:
- `+ - * / = < <= > >= | &` dyadic
- `?` ternary (the cond form infix: `(t ? a b)`)
- `%` mod
- `<-` pin, `->` peek (the collection accessors: `(t <- k v)`, `(t -> k d)`)

pure lisp is a subset of ll: `?` is still the cond form at the head of a
list, and any lisp-mode program becomes infix-safe by wrapping its bare
punct symbols in parens (`(+)` is `+` as a value) -- the lisp semantics
are unchanged.

the full spec
is [CLAUDE.md](CLAUDE.md) -- the root test file CLAUDE.l in a code fence, so
the spec stays green.

## code examples

selected identities

- `1 = (\ x x)`
- `0 = (\ _ 1)`
- `8 = 3 2`
- `65536 = 2 2 2 2`
- `-1 = i * i`
- `log -1 = i * pi`
- `i = (1 / 2) -1`
- `5.0 = abs ~(3 4)`
- `12 = 3 (+ 1) 9`
- `2.0 = (1 / 2) 4`
- `"ababab" = "ab" * 3`
- `'(1 2 1 2) = '(1 2) * 2`

hello world

```
."hello world\n"
```

fizzbuzz

```
(100
 (\ n (: f (? (n % 3) "" "fizz")
         b (? (n % 5) "" "buzz")
         _ .(? ($f | $b) (f + b) n)
         _ ."\n"
       (n + 1)))
 1)
```

## build & test

`make` builds the host binary `out/host/ll`. `make test` is the commit gate:
it runs the test corpus through both `ll` and the self-hosted bootstrap `ll0`.
`make test_all` adds the freestanding kernel (qemu) and tool diffs.
