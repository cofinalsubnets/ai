# Brief: interleave galaxies into the number band

A handoff plan. Recon done (core thread); this is for the session that picks up the edit.
Core territory (`ai.c`/`spec.l`) — whoever runs this *is* the core thread for the duration.

## Decision (settled)

A **constellation** (star *or* galaxy) orders by its **net**, forming one contiguous numeric
band. Object arrays (trays) stay value-built. Target total order:

```
() < name < string < ⟨stars + galaxies, by net⟩ < link < tray < tablet < hot
```

Galaxies **interleave** with scalars by net value (not a separate sub-band). A galaxy sits
exactly where its net's scalar sits; on a net tie a scalar seats below the galaxy.

## What recon already established (don't re-derive)

- **Authoritative order today** lives in `ai.c`, not the docs: `ai.c:6049` comment +
  `cmp_rank` (`ai.c:6055`) + `cmp3` (`ai.c:6091`). `test/spec.l:92` and `theory.html` (lattice &
  order) agree with it.
- **Compare order is deliberately decoupled from the dispatch enum** (`ai.c:6053`). The
  `enum q` (`ai.h:312`: `KMint,KCharm,…,KString,KChain,KMap,KHot`) puts numbers *below*
  string; `cmp_rank` remaps to the true-blue order. **Do not touch `enum q` or the dispatch
  matrices** — only the `cmp_rank`/`cmp3` remap.
- **The bug:** `cmp_rank` bands by storage kind, so `KArr*` → rank ≥6 (above `link`). In
  `cmp3` a rank-≥6 array then falls through every case (`nomp`/`isnum`/`strp`/`formp`) to the
  **hash fallthrough** at `ai.c:6108` — so galaxies sort by representation hash,
  value-meaningless. Confirmed: `sort (L @(9 9) @(1 1) @(5 5))` → `(@(5 5) @(1 1) @(9 9))`.
- **Trap — surface `<`/`=` never reach `cmp3` for arrays.** They divert to the broadcast
  engine `lvm_vbin` and return an elementwise **mask**. This stays. So the new order is
  observable through `sort` and map-key ordering, **not** through `@<@`. This dictates how
  you test (Edit 3).

## Edit 1 — `cmp_rank` (`ai.c:6055`)

Band numeric arrays into the number band; leave trays above chain.
- Galaxies (`KArrZ`/`KArrR`/`KArrC`) → return `2`.
- Trays (`KArrO`) → keep `(int)k` (unchanged).
- **Verify first:** that `ai_kind` refines a numeric array to `KArrZ/R/C` (not a bare
  `KVec`), and whether `KVec` is ever a live kind for a value (`ai.h:298,313`). Band
  accordingly — use `galaxy?`-equivalent logic, not a raw range, if `KVec` is live.

## Edit 2 — `cmp3` number-band branch (`ai.c:6098`)

Today `isnum(a)||Cp(a)` is scalar-only; a rank-2 galaxy would skip it and hit the hash
fallthrough. Add a constellation comparator that fires when either operand is a rank-2 array:
1. Compare **nets** (`ai_net` → `ai_zn`; re then im lexicographic — mirror the complex
   compare at `ai.c:6099-6103`).
2. Net tie → **scalar before array** (star < galaxy).
3. Array vs array, net tie → **shape lex, then content lex** (recurse `cmp3` over cells).

Keeps `<` a strict total order (antisymmetry holds — the structural tiebreak prevents
equal-net collisions). Empty galaxy nets 0 (monoid unit), seats at 0.

## Edit 3 — tests (`test/spec.l`)

Route order assertions through `sort` (→ `cmp3`) and assert via `show` — **not** infix `<`
(masks on arrays) and **not** `=` on result lists containing arrays (also masks). Add near
`test/spec.l:92`:
- `(show (sort (L @(2 4) 5 @(1 1)))) = "(@(1 1) 5 @(2 4))"` (nets 2, 5, 6).
- star<galaxy on net tie: scalar `3` before `@(1 2)` (net 3).
- tray stays above link: a chain before `@('a 'b)`.
- demotion still holds: `(@(5) = 5)`.

`make test` regenerates `proof/rocq/gen.v` via `tools/spec2coq.l`.

## Edit 4 — Rocq (`proof/rocq/spec.v`)

`O` has 6 keys, no set band (already a documented near-omission in `theory.html`, lattice & order). After the C
lands, decide: fold galaxies into `Onum` by net, or keep arrays as an explicit omission. Make
the proof track the binary, not lead it.

## Edit 5 — docs (`theory.html`, lattice & order)

- Rewrite the band one-liner: `set` splits — galaxy folds into the number band by net, tray
  stays above chain.
- Add the **surface-`<`-broadcasts caveat** to the "the comparator *is* the engine of sort"
  line: surface `<`/`=` on arrays give a mask; the scalar total order is `cmp3`, used by
  `sort` + map keys.
- Grep `index.html` and `theory.html` for order demos; update the band one-liner in `theory.html` by hand.

## Verification

`make test` (host + ai0 **twice** → must print zz-fin), then `make test_all` — this changes a
core comparator that both `sort` and map-key ordering ride, so the kernel + tool diffs matter.

## Coordination ⚠️

A separate thread is editing **CLAUDE.md to match the *current* binary** (galaxy/tray above
`link`). This change moves that order — their edit lands stale on contact. Sync before either
merges: they should document the **target** order above, or wait for this.
