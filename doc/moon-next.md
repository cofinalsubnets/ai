# moon-next — the 32-bit layout hole, then typeof, then asm goto

Three items for the mooncc thread, in the order I'd take them. The first is a **confirmed
silent miscompile** and outranks the other two; the other two are assessments of the GCC
extensions that gate real-world C (and, eventually, a kernel).

Confidence is not uniform below. Item 1 was **probed against the binary** — recipe included,
re-run it. Items 2 and 3 come from a read-only survey; the file:line refs were accurate at
`1c559dbc` but re-check them at the point of edit rather than trusting them.

---

## 1. struct layout is wrong on thumb1 and thumb2 (silent) — RESOLVED

**Fixed** (post, uncommitted at time of writing): the target is now threaded into the parse
state (`psnew tgt`), and `tsz`/`talign` take the pointer/word width from it via `psword ps`
(4 on the thumb ABI, 8 else) — mirroring gen's `(wsize g)` exactly. `cparse` keeps a
64-bit-default alias for the law tests; the driver calls `cparse-t <>pp tgt`. gen's data
emitter was the twin site: `cgimage` rounded the span to 8 and `imgbytes` baked pointers as
`(fix 8 abs64)` — both now word-sized (`abs32` on t32). `test_thumb1` gained the cross-ABI
catch: a gcc-built pointer-bearing struct read back by a mooncc function (offset 4), which the
gate confirms FAILS with the width reverted to 8. The rest of this section is kept as the
record of what was wrong.

`parse.l:158` sized a pointer at a hardcoded 8, and `talign` (`parse.l:164`) aligned it to 8:

```
(tsz ps ty) (? (ptr? ty) 8 ...)
```

`tsz` takes only `ps`, and the parse state carries **no target**, so the 8 is structural
rather than conditional — there is no path by which it could answer 4. gen's twin
(`gen.l:261`) is correct, using `(wsize g)` = 4 on t32.

That would be harmless if parse only ever folded `sizeof`. It isn't: `playout`
(`parse.l:302-339`) builds **struct layouts** at parse with those widths, and the resulting
`stag` table rides out with the AST (`parse.l:1184`) into gen, which trusts it. So every
struct containing a pointer is mislaid on both 32-bit targets, and member access reads the
wrong offset. No scare — it just quietly computes the wrong address.

**Probe:**

```c
struct S { int *p; int x; };
int f(struct S *s){ return s->x; }
```

```
mooncc -c -t thumb1 -o off.o off.c && llvm-objdump -d --triple=thumbv6m off.o
```

thumb1 emits `adds r0, #0x8`; thumb2 emits `addw r0, r0, #0x8`. Reference:

```c
_Static_assert(sizeof(struct S) == 8, "size");
_Static_assert(__builtin_offsetof(struct S, x) == 4, "off");
```

passes under `arm-none-eabi-gcc -mcpu=cortex-m0 -mthumb`. Correct offset is 4.

`sizeof(int*)` also folds to 8 at parse on **every** target, x64 included — benign there
only because 8 happens to be right.

**Fix:** thread the target into the parse state (`psnew`, `parse.l:134-145`); the driver
resolves `tgt` (`moon.l:52-54`) before parsing, so it is available. Then `tsz`/`talign` take
the width from `ps` the way gen takes it from `g`.

Note what will *not* work: deferring the fold to gen. Parse folds early on purpose — an
array bound needs the constant at parse time, and gen's `szof` lane is too late
(`law.l:200-203`).

Two parse-side/gen-side twins are now known to have drifted (`tsz`, `talign`). Worth
considering whether they should share one definition rather than being kept in sync by hand,
since a divergence here is invisible until it miscompiles.

**Gate:** `test_thumb1` misses this — it exercises scalars and divide, never a
pointer-bearing struct. Whatever fixes it should add one.

Related but distinct, already open: gen's data emitter lays an `int g` as 8 bytes on thumb1.
Same 32-bit data-model family, different site.

---

## 2. typeof — two tiers, ship the cheap one

`typeof(TYPE)` is roughly six lines and no gen change:

- a new arm in `pbty` (`parse.l:341-388`) that wants `(`, recurses into `pcty`
  (`parse.l:391-395`), wants `)`, answers the type verbatim;
- teach `tkbty?` (`parse.l:147-151`) that a type begins there — without it every ambiguous
  site (cast vs paren-expr at `parse.l:493`, block item at `:936`, param list at `:945`, …)
  misreads `typeof(x) y;` as an expression statement.

No lexer change: match `typeof`/`__typeof__` as an `id` by text, the way `__builtin_va_arg`
(`parse.l:424`), `__attribute__` (`parse.l:58-59`), and `asm` (`parse.l:740-741`) already
are. That picks up `__typeof` free.

`typeof(EXPR)` is the expensive tier, and the cost is one specific narrowness. `ptype`
(`parse.l:183-192`) is the parse-side expression typer; it handles `var`, `dot`, `deref`,
`cast` and answers `()` for everything else — literals, `bin`, `call`, `addr`, and **any
global**, since the parse state has a `'locals` table and no globals table.

For `sizeof` that is fine: a miss degrades to a deferred `('szof e)` node (`parse.l:509`)
that gen resolves. **`typeof` has no such escape** — a declarator needs a concrete type
immediately to build `('ptr t)`/`('arr t n)` and feed `playout`, so every `ptype` miss is a
hard parse error rather than a graceful fallback.

Order of work if it's wanted, roughly by payoff:

1. globals — a `'globals` table in `psnew`, written at the `gdecl` sites (`parse.l:1108-1141`,
   `:1057-1064`). Without it `typeof` on any file-scope variable fails.
2. literals — `num`/`flo`/`str` → `'long`/`'double`/`('ptr 'char)`, matching gen at
   `gen.l:713-718`.
3. calls — the return type is already available in `ps 'sigs` (`parse.l:139`).
4. `addr`/`clit`/`post`/`asn` — operand type.
5. `bin` — usual arithmetic conversions plus pointer scaling; mirrors `ubin` (`gen.l:255`).

**Recommended:** ship tier one plus the four `ptype` cases that already work. That covers the
dominant real use — `typeof(x) tmp = x;` over a local, and the `min`/`max`/`swap` macro
hygiene pattern. Add globals and literals as a cheap follow-up. Items 5+ only when something
being compiled actually demands them.

⚠ **Do item 1 first.** `typeof`-derived pointer types would inherit the bad width, spreading
a layout bug into more places.

Hazard worth naming: extending `ptype` grows a second parse-side copy of gen's type
propagation. `tsz`/`talign` already drifted exactly this way (item 1). Any divergence is a
silent miscompile.

---

## 3. asm goto — the allocator is not the problem

The obvious fear — that a terminator with multiple successors would break the tuned register
allocator — **does not apply.** `hasasm` already disables register homing for any function
containing asm (`gen.l:3909`, `:3913`), and the vmap flushes at every label (`gen.l:3375`),
so nothing is expected to live in a register across an asm statement. `alive` already returns
the whole universe for both `goto` (`gen.l:3236`) and `asm` (`gen.l:3238`). Keep homing off
under `hasasm` and the allocator needs no change at all.

The real blockers:

**a. The raw blob can't name an outer label.** `cgasm` assembles the body immediately via
`holo-bytes` (`gen.l:2966`) with an empty pre-bound label table, so any label not defined
inside the template hits `(scare 'undef-label ..)` (`holo.l:130`). There is a clean hook,
though: raw is lowered verbatim by every backend (`x64.l:361`, `arm64.l:349`, `thumb2.l:225`,
`thumb1.l:281`), and `chunk-len`/`resolve` (`holo.l:88-89`, `:125-133`) already handle inline
`('fix w kind label aux)` items anywhere in the stream. A raw carrying an unresolved fix
would lay out and resolve against the **outer** function's label table for free. What's
missing is a holo entry point — a variant of `assemble-at` (`holo.l:208`) — that assembles
while leaving a whitelist of external labels as fix placeholders instead of scaring.
`laylax` (`holo.l:154`) would need to treat such a fix as its widest form.

**b. `cfoldir`'s pend merge is the one correctness hazard.** At `gen.l:2016-2018`, a label
with no recorded pending state that is linearly live inherits the fall-through state
verbatim. An invisible in-edge — a branch out of an opaque raw blob into a C label — makes
that join unsound: constants assumed at L would not hold on the asm edge. Minimum viable fix
is to collect the asm-goto target labels per function and add them to the `backs` table
(`gen.l:1985-1994`) so they take the existing "assume nothing" path. Cheap, and mirrors
back-edge handling exactly — which exists for precisely this reason.

**c. Surface.** `pasm` (`parse.l:734-776`) hardcodes three colons as `s1`/`s2`/`s3`; a fourth
(GotoLabels) needs an `s4` and a fifth field on the `('asm ..)` node, which ripples to every
positional consumer (`gen.l:2899`, `:2917`, `:2918`, `:2944`, `:3124`, `:3238`, and the
goldens at `law.l:618-629`). `asmsub` (`gen.l:2881`) must learn `%lN` — currently `'bad` at
`gen.l:2893` — and substitute the *mangled* label `fn.NAME`, sharing the mangling with
`gen.l:3374-3375`. `asm goto` is implicitly volatile and (pre-GCC-14) takes no outputs.

Everything else already refuses or resets on raw: `unframe` bails (`gen.l:1868`), `deadcell`
dirties (`:2229`), `deaddef` treats it as a barrier (`:2324`).

**Assessment:** about a week, touching parse, one gen pass, and one new holo entry point — and
not the allocator.

---

## sequencing

Item 1 is a correctness bug on shipped targets and should go first regardless of appetite for
the rest. Item 2 pays off in ordinary userland, not just kernel headers, and is cheap in its
first tier. Item 3 is close to kernel-only — worth doing when something you actually want to
compile demands it, not before.

None of the three brings Linux into range on its own. The kernel additionally wants
`__label__`, computed goto, `_Generic`, and attribute semantics that change codegen. Nearer
targets that exercise the same surface without the cliff: busybox, sqlite, lua, zlib, musl.

## correction to a stale premise

The "typedef-set hybrid" of `1c559dbc` is in `fmt.l` (`harvest`, `fmt.l:69-110`) — a textual
scan for `typedef … NAME;` used by moonfmt to decide `word*p` → `word *p` spacing. It is not a
parser facility and not a type table. The parser's known-type set is `ps 'types`
(`parse.l:135`), populated by `tdeflist` (`parse.l:1024-1032`), with C block scoping honored
by `shadow1`/`unshadow` (`parse.l:908-920`).
