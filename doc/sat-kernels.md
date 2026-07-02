# the sat kernels — a domain-specific compiler over asm/

`sat/flat.l` is the answer to a question: can the in-tree assembler carry a *domain-specific
compiler* — not a general codegen pass, but one app compiling its own hot loops? It can. The
CDCL SAT solver's three hot loops are hand-written in asm/ neutral IR, assembled **at
solver-build time, specialized to the instance** (section displacements baked as immediates,
one kernel set per `nvars`, cached), and installed through the `nif` seam. The result runs
with the reference C solvers: fastest in the field on PHP(5) and PHP(6), within ~10% of
minisat on PHP(7), ahead of glucose on PHP(8) and on net time (`bench/bench.html`, second
table; `bench/satrace.sh` reproduces it).

the lineage: `sat/sat.l` is the readable tablet-based solver and stays the oracle —
`sat/flat.l` runs AFTER it (`cat sat/sat.l sat/flat.l | ai`) and gates differentially
against its DPLL baseline on every load. `make test_sat` runs the whole stack.

## the shape

State lives flat, laid out for `ldx`/`stx` (the authoritative layout comment is at the top
of `sat/flat.l`): one `fx` cask holds the header scalars (top/qhead/level/aru/wvu/vinc) and
the per-variable sections (trail, levels, reasons, watch heads, values, activities, phases,
a seen scratch); two growable casks hold the clause arena and the watch nodes. Literals are
encoded (`+v → 2v`, `-v → 2v+1`, so negation is xor 1); `val[v]` stores the *true encoded
literal itself* (0 = free), making lit-eval one load and one compare. VSIDS activities are
integers — the increment grows ×21/20 per conflict and everything shifts right 8 past 2²⁴,
so decay is a shift and ancient bumps fading to zero is the intended semantics.

Three kernels, each with an interpreted **twin** over the same memory:

* `bcp (fx ar wn)` — two-watched-literal propagation; returns the conflict cid or −1.
* `conf (fx ar wn confl)` — the *whole* conflict: 1-UIP absorption with inline activity
  bumps, self-subsumption minimization compacting the learnt clause in place in the arena,
  glue + backjump level in one pass, the trail pop with phase saving, the learnt commit
  with both watches, the asserting assignment; returns `(cid<<6)|glue`, −1 at level 0.
* `dec (fx)` — highest-activity free variable, saved-phase polarity, assign; 0 means SAT.

Lisp keeps only the cold path: restarts, learnt-DB reduction (worst-glue half dies at a
level-0 restart, glue ≤ 3 immortal, survivors compact by `pour`), and activity decay. The
caller pre-ensures arena room before `conf`; kernels never grow a cask.

## the kernel contract (reusable for any nif kernel)

* `(nif code interp src arity)` installs machine bytes as an applicable value. lvm ABI:
  g=rdi, Ip=rsi, Hp=rdx, Sp=rcx; params arrive TAGGED at `Sp[i]` in source order.
* Guards first, pushes second: a cask param is `test 1` (fixnum → deopt) then its ap word
  against `(apof (cask 1))` as a movabs immediate; its bytes sit at `[[v+8]+16]`. Because
  every deopt fires *before* any push, the machine sp is balanced on every path, which is
  what makes callee-saved registers (r3, r11–r14) usable with plain push/pop.
* Epilogue: tag the result (`shl 1; or 1`), store to `Sp[0]`, `Ip += 16`, jump — that lands
  on `lvm_ret` in the value cell. Deopt (arity ≥ 2): load `[Ip+8]` (the interp fallback),
  enter its body — the args are still on Sp, so the twin resumes seamlessly.
* The twin IS the spec, phase for phase, and three things at once: the deopt fallback (so
  native is never wrong), the portability path (arm64, or any image where the egg mopped
  `nif` — kernels build only under `(lit? nif)` and arch x64), and the differential oracle:
  the `fknob` box forces all twins, and the gate asserts kernels ≡ twins verdict for
  verdict on top of the 150-instance fuzz against DPLL.
* Specialization is cached (`fkers`, keyed by nvars) and costs ~30ms once per size. Time
  solves WARM — `satrace.sh` pre-warms `(fbcpk (php-vars h))` outside its clock, exactly as
  it already excludes interpreter warmup. (Every scoreboard before 2026-07-02 charged
  assembly to the solve; don't repeat that.)

## the numbers (warm, all shootout verdicts correct)

| ms | ai | minisat | picosat | kissat | cadical | glucose |
|---|---|---|---|---|---|---|
| PHP(5) | **1** | 4.2 | 2.8 | 3.7 | 4.5 | 4.2 |
| PHP(6) | **2** | 7.2 | 5.3 | 5.5 | 5.5 | 6.6 |
| PHP(7) | 22 | 38.5 | 28.1 | 18.3 | 8.0 | 43.3 |
| PHP(8) | 131 | 269 | 228 | 71.6 | 12.2 | 913 |

third in the whole field by net time (cadical 31, kissat 101, **ai 161**, picosat 262,
minisat 327, glucose 963) — ahead of every classic CDCL, trading blows with kissat.

Where the journey started (interpreted tablet solver, 2026-07-01): ~45× slower than
minisat on PHP(7). The rungs: flatten the state (proves the layout, slower interpreted) →
bcp kernel (~10× over the twin) → learnt-DB reduction + minimization (kills the PHP(8)
superlinear bloat) → conf + dec kernels (the per-conflict path was ~90% of what remained)
→ warm timing + cadence tuning. Each rung was phase-profiled before it was built — the
clock-delta split of the driver loop (bcp / conf / cold path / dec) found every whale.

## the watcher-vector experiment (built, measured, kept out)

The full minisat watcher architecture — per-literal contiguous vector segments, blocking
literals, an in-watcher binary-clause lane, swap-remove slides, newest-first backward walk,
grow-by-clean-abort — was built, gated green, and measured against the intrusive-node
design, warm, both ways: nodes win everywhere here (PHP 4/42/980 vs 6/57/981; random 3-SAT
n=1000: 12–13ms vs 22ms). CDCL slide churn is constant and an O(1) node relink beats
vector growth machinery; a blocking literal only pays when a touched clause is *already*
satisfied, which conflict-storm propagation rarely grants. The spike survives with its
verdict in `doc/proto/sat-watcher-vectors.l` — a sound base if a blocker-friendly workload
(high satisfied-visit rates, e.g. large industrial SAT instances) ever shows up.

## fbva — the factoring pass, and how it was found

Ablating cadical itself (probe the binary, never trust a prior) located the pigeonhole
killer: with **every** technique disabled except `factor`, cadical solves PHP(8) in 14ms;
add `--no-factor` and it collapses to minisat-class. Factoring is **bounded variable
addition** — introduce a fresh variable to stand for shared clause structure — and adding
definitional variables is the *extended resolution* move: PHP has polynomial ER
refutations (Cook 1976) where plain resolution — and therefore ANY amount of clause
learning — is provably exponential (Haken 1985). Cadical doesn't search pigeonhole
faster; it re-encodes it into a proof system where the search is easy. (Beware the
ablation trap en route: single-flag ablations all read "no effect" because the ensemble
is redundant, and one invalid option — `--preprocessing=1` — produced 3ms "results" that
were the error path. Check exit codes.)

`fbva` (sat/flat.l) is the Manthey–Heule–Biere greedy: for a literal l, grow M_lit ×
M_cls with every (m | C\{l}) present, then a fresh x replaces |M_lit|·|M_cls| clauses
with |M_cls|+|M_lit|+1. Three details carried ALL the value, found by diffing our
factored output against cadical's (decoded from its binary DRAT proof — the added
definitional clauses are right there):
* **structured tiebreaks**: on symmetric instances every match count ties, and a
  hash-order pick yields ragged overlapping groups that HURT search (they slowed even
  cadical 2.5× when fed our early output). Max count, ties to the lowest literal →
  contiguous groups → the commander/AMO-tree structure. This one change took our PHP(8)
  from 2713ms to 120ms — the entire prize was in the tiebreak (the "structured" in
  structured reencoding).
* **complete definitions**: emit the reverse long clause (x | ¬m₁ | … | ¬mₖ) too, so
  x ↔ AND(M_lit) propagates both ways instead of leaving x free for CDCL to wander on.
* **no aux cascade**: factor the original structure only (`fbvac0`); re-factoring the
  definitional clauses tangles instead of laddering (measured ~9× worse).

Soundness rides the existing discipline: equisatisfiable both ways (resolving on x
recovers every original; a model extends by x := AND(M_lit)), models project by dropping
vars > nvars, and the whole differential gate — 150 fuzzed instances vs DPLL, #SAT ==
Lucas — flows through the pass since `fcdcl` runs it by default (`fbva0` pins it off).
`fmk` lays the solver out for a power-of-2 variable bucket so the kernel cache survives
BVA's varying variable counts (phantom vars are sound: never watched, decided dead last,
popped clean). Cost on unstructured instances: ~8µs/clause of intake, the floor of an
interpreted pass.

## what the remaining distance is

kissat (72ms) and cadical (12ms) on PHP(8). Cadical's edge over our 131ms is its faster
plain core (103ms sans factor — chronological backtracking, stable/focused mode
switching, aggressive shrinking) *multiplied by* better factoring integration
(inprocessing-scheduled, not one-shot). All of that is solver research living in the
lisp cold path — which is exactly where that kind of logic belongs now that the hot path
is native.
