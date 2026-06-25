# Plan: the heap-image snapshot (a precompiled boot image)

Goal: **boot from a serialized heap image instead of evaluating the corpus.** Today `boot()`
(host/main.c) hands `ai_evals_` the egg+prel+ev+post+asm+bao SOURCE string and the self-hosted
compiler MATERIALIZES the whole runtime at startup — measured **~233 ms cold start** (the setup-row
bench, ai 2nd-worst). The snapshot makes that ~instant: dump the post-boot heap ONCE at build time,
embed it in the binary, and at startup `mmap`+relocate it in with no eval. (Design doc, like
galaxy-order.md / serialize.md / stream.md — not yet built.)

## Why — three payoffs, in priority order

1. **Cold start ~233 ms → near-zero** for the WHOLE runtime (every script run, every repl, every
   bench wall-clock). This is the standalone win; it pays off even with no glaze.
2. **The glaze bake becomes free.** Adding `ai/glaze/emit.l`+`auto.l` to the boot corpus costs
   ~+810 ms today (it is ~2000 lines of ai + ~50 native-compiling asserts, all eval'd at startup —
   measured). Inside a snapshot it is precompiled: **always-on transparent JIT, zero startup cost,
   like luajit** — which is exactly what the bake needs (and why the naive bake was abandoned).
3. **The GC-footprint tax goes away.** The image lives in an out-of-pool IMMORTAL region (extend
   ai.c's existing "out-of-pool short-circuit ... immortal, never copied", ai.c:667), so the moving
   collector never copies the egg/glaze closures — no per-collection cost from a bigger baseline.

## Mechanism — a binary heap dump + relocating load

The heap is a two-space copying arena; every object's first word is its `ap` (a live external
reference: a C `lvm_*` pointer or another heap pointer); fixnums are odd-tagged, heap pointers even.
A snapshot is a flat blob of all objects reachable from the root (`book`), with two pointer classes
rewritten so it can be re-based and re-linked in a fresh process:

- **Internal heap pointers** → stored as OFFSETS into the blob (re-based to `image_base+offset` on
  load). ASLR-safe: nothing absolute is stored.
- **C `lvm_*` pointers** (the aps/hots/nifs — `lvm_chain`, `lvm_flo`, every nif entry, the C-resolved
  hooks num-ap/add/mul/help) → stored as a SYMBOLIC INDEX into a fixed table, re-resolved to the
  current `.text` address on load. The enumeration already exists: the egg `mop` (ai/egg.l) walks and
  deletes every `lvm_*` nom — reuse that set as the relocation table.
- **Out-of-pool immortal constants** (`ZeroPoint`/`()`, the interned const region) → a tagged
  "resolve-to-C-const" entry, fixed up to the live const on load.

Load is a single linear pass over the blob (relocate offsets + re-resolve the lvm_* table), then
`pin book` from the image root. Far cheaper than eval (a memcpy + a fixup walk, not a compile).

## Phases (each: deliverable · gate · go/no-go)

**Phase 0 — SPIKE: prove the round-trip (de-risk before committing).**
Two debug nifs: `(image-dump path)` walks reachable-from-`book`, writes the blob; `(image-load path)`
reads it, relocates, installs `book`. Dump after a normal boot; in a FRESH `ai`, load it and run a
handful of forms (`(+ 1 2)`, a captured closure, a map lookup, a bignum, a twin). · GATE: loaded heap
== eval'd heap on those forms. · GO/NO-GO: if relocation + lvm_* re-resolution round-trips cleanly,
proceed; if the pointer graph has a kind that won't serialize (a live port/task, a W^X toast), scope
it out (snapshot is taken at a quiescent point — see Phase 4).

**Phase 1 — The serializer.** Generalize the spike dumper to EVERY kind (chain, pack/gem/twin/tray,
str, mint, nom/KNom, map/tablet, closure with its `fn_src` cell, nif, cask). Header = {root offset,
lvm_* table, arch+pointer-size+version stamp}. · GATE: dump→load→`(= the whole book)` structurally;
run test/spec.l against a loaded image == against a booted one (2693 pass).

**Phase 2 — The relocating loader + the immortal image region.** Map the blob into a dedicated
out-of-pool region the collector skips (extend `gcp`'s out-of-pool check). · GATE: a full GC after
load leaves the image intact (the image is never copied); spec green; valgrind clean (`make valg`).

**Phase 3 — Build integration.** Build step: `ai --dump-image out/lib/image.bin` (boot fully, dump).
Embed via `objcopy`/a linked C array → `image.o`. `boot()`: if the image stamp matches this binary,
`image-load` it; else FALL BACK to eval'ing the egg (so a stale/missing image is never fatal). Image
is arch+build-specific → a Makefile dep on prel/ev/post/asm + the binary. · GATE: `out/host/ai`
boots from the image; cold start measured (target <20 ms, from 233); spec+ai0 green.

**Phase 4 — Bake the glaze (the payoff).** Split emit.l/auto.l's inline asserts into
`emit-test.l`/`auto-test.l` (the asm/asmtest.l precedent) so the baked lib is assert-free; add the
assert-free glaze to the boot corpus BEFORE the dump, x86-64-gated. The snapshot is taken with the
glaze loaded and `ev` already rebound to `auto-ev`, but BEFORE any closure is natively compiled (no
W^X arenas to serialize — natives JIT lazily at first `ev`, as today). Remove run.sh's glazed list;
the bench just runs `ai bench.l`. · GATE: test_glaze green; ALL bench checksums unchanged; cold start
still <20 ms; every bench glazes transparently.

**Phase 5 — Cross-arch + cleanup.** aarch64 host → its own image (no glaze). wasm/kernel → keep the
eval path (or their own image later). Document; update CLAUDE.md (the egg section) + the setup-row
note. The "even on an MCU, try" frontier (a per-arch aarch64 emitter so the glaze runs everywhere)
rides on this once images are per-target.

## Risks / open questions

- **lvm_* completeness** — miss one C pointer and load crashes. Mitigation: derive the table from the
  mop's lvm_* enumeration; assert at dump that every non-heap word0 is in the table.
- **Quiescent dump point** — ports/tasks/finalizers/W^X natives must NOT be live at dump. The
  assert-free glaze + dumping right after boot (before any user ev) keeps the heap to pure closures.
- **Relocation correctness per kind** — the Phase-0 spike is exactly to flush this out cheaply.
- **Maintenance** — the image rebuilds whenever prel/ev/glaze change (a Makefile dep); the stamp +
  eval fallback make a stale image safe, never wrong.
- **Existing infra to lean on** — the generational collector already RELOCATES objects and has the
  out-of-pool/immortal short-circuit (ai.c:667, the gen_*_relocate machinery); serialize.md's
  source-level round-trip is an independent cross-check (a dumped closure should `show`-match its
  eval'd twin).

Relates: the egg (ai/egg.l, the double-sat), [[glaze-float]] (the bake this unlocks), serialize.md
(source-level serialization), gengc.md (the collector + immortal region).
