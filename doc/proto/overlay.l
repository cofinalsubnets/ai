; ============================================================================
; PHASE 0 SPIKE PLAN -- pluggable static types via an extended die (the "overlay")
; ============================================================================
; This is a PLAN, not a finished spike. It lays out the smallest experiment that
; answers the one question the whole pluggable-types direction rests on:
;
;     Can a user DEFINE a type domain in ordinary ai, hand the compiler a CHECKER
;     for it built from the existing fixpoint harness, and have that checker
;     (1) ERASE cleanly -- removing it changes no runtime behavior -- and
;     (2) REJECT a real mismatch through the harness, not a bespoke pass?
;
; If Phase 0 shows both, the direction is real and Phase 1 (ergonomics) + Phase 2
; (dial the domain up to uu's dependent types) are additive. If the seam fights,
; we learned it in ~2-3 sessions instead of a month. See memory pluggable-types,
; and doc/analysis-unification.md (this is literally its "make the abstract-interp
; DOMAIN pluggable" step, done as a standalone spike first).
;
; THE CORE STANCE (do not lose): the FUNDAMENTAL type system stays FREE -- no
; required annotations, ever; the glaze PROVES what CL makes you assert. The
; overlay is OPTIONAL and OBSERVE-ONLY: it may reject or annotate, never change
; what runs. That erasability is exactly property (1) and is what keeps "free"
; intact under the overlay (Bracha's pluggable-types rule). Ergonomics: infer
; WITHIN a function, declare at its BOUNDARY (like HM/gradual) -- never the CL
; per-subexpression annotate-everything.

; ----------------------------------------------------------------------------
; PIECES WE ALREADY HAVE (reuse map)
; ----------------------------------------------------------------------------
;   * monofix (ai/prel.l) -- the shared monotone-fixpoint driver. The overlay's
;     inference is just another client (like smfix / ho-fix / ale:propagate).
;   * doc/proto/kinds.l -- a 67-line abstract KIND inference over `:` bindings via
;     a seminaive fixpoint (join / transfer / kindof / fix). The overlay is
;     kinds.l with the LATTICE, JOIN, TRANSFER and LITERAL-KIND made USER-SUPPLIED
;     instead of hardwired to N<Z<R<C. Start by copying kinds.l and lifting `dom`
;     out as a parameter.
;   * coins / dies (newtypes Stage 0, ~65 refs in ai.c) -- the RUNTIME face of a
;     die (a die + payload, riding +/*). Phase 0 does NOT use the runtime face:
;     see the scope decision below.
;   * the wev/opfix source->source prepass seam -- where a check pass hooks (it
;     runs pre-analysis, sees the whole form). The overlay CHECKER runs here; it
;     returns the form UNCHANGED (observe-only) plus a report.

; ----------------------------------------------------------------------------
; SCOPE DECISION for Phase 0: dies are STATIC LABELS, not runtime coins.
; ----------------------------------------------------------------------------
; A die has two faces: a RUNTIME coin (rides +/*, alters the algebra) and a
; STATIC signature (a label the compiler propagates). Unifying them ("one die,
; two faces") is the eventual "extended die mechanism" -- but for Phase 0 we
; exercise ONLY the static face. Runtime values stay plain numbers; the dies live
; solely in the type table + the abstract domain. This makes ERASURE trivially
; true (the runtime never sees a die) and ISOLATES the question we care about:
; does the checker-from-the-harness seam work? Wiring the runtime-coin face back
; in is Phase 1+, and it's an ORTHOGONAL axis (coins alter semantics; the static
; overlay must not).

; ----------------------------------------------------------------------------
; THE SURFACE -- a user's type system is a SEPARATE ARTIFACT, not inline clutter
; ----------------------------------------------------------------------------
; Two ordinary ai values the user supplies. Nothing decorates the code itself --
; that is the anti-CL move and it makes erasure structural (drop these, code runs).
;
; (A) a DOMAIN: the user's universe of constructors + how they combine. Exactly
;     kinds.l's {dice, join, transfer, litdie}, but the user writes it:
;
;         SKETCH -- a units domain
;         (: units
;            (dice   '(meters seconds area top bot))            ; the constructors + lattice caps
;            (join   (\ a b (? (id? a 'bot) b (id? b 'bot) a (id? a b) a 'top)))  ; discrete: unequal -> top(clash)
;            (litdie (\ e 'bot))                                ; bare numerals carry no unit (bot = "unconstrained")
;            (tr     (\ op a b                                  ; transfer for +/*: the user's algebra
;                       (? (id? op '+) (? (id? a b) a 'top)     ; + : like units add, else CLASH
;                          (id? op '*) (? (&& (id? a 'meters) (id? b 'meters)) 'area 'top)  ; m*m -> area
;                          'top))))
;
; (B) a SIGNATURE TABLE: name -> (param-dies.. . result-die), the BOUNDARIES.
;     One line per typed function; untyped functions are simply not checked
;     (gradual: the overlay covers what you opt in, ignores the rest).
;
;         SKETCH
;         (: sigs '((room-area (meters meters) . area)
;                   (bad       (meters seconds) . area)))       ; a deliberately-wrong sig for the reject demo
;
; The user's PROGRAM is untouched ai:
;         (: (room-area w h) (* w h)
;            (bad w t)       (+ w t)                            ; meters + seconds -- a clash
;            ..)

; ----------------------------------------------------------------------------
; THE ENGINE -- kinds.l's fixpoint, domain-GENERIC (dom passed in)
; ----------------------------------------------------------------------------
; Mechanically lift kinds.l: kindof / join / transfer take `dom`. A call site
; `(f a b)` where f is in `sigs` uses f's declared param/result dies (the boundary
; -- infer WITHIN f, trust the sig ACROSS f); a call to an untyped f yields the
; domain top (unknown, never a clash). The `:` letrec* still needs the fixpoint
; (mutual recursion), driven by monofix.
;
;     SKETCH (the seam -- ~kinds.l generalized)
;     (kindof dom sigs env e) (?
;        (charm? e)  ((dom 'litdie) e)
;        (nom? e)    (look env e)
;        (atom? e)   'top
;        (: h (cap e) as (map (\ s (kindof dom sigs env s)) (cup e))
;           (? (member? h '(+ *)) ((dom 'tr) h (cap as) (cap (cup as)))
;              (id? h '?)         ((dom 'join) (cap (cup as)) (cap (cup (cup as))))
;              (sig-of sigs h)    (result-die (sig-of sigs h))     ; a typed callee: use its boundary
;              'top)))
;
;     (check dom sigs prog) -> a list of CLASHES: for each (name params . res) in
;     sigs, bind params to their dies, infer the body to a fixpoint, and flag if
;     (a) any subexpression's die is the domain's clash element (top here) where
;     the user's tr said "clash", or (b) the inferred result-die does not join-
;     below the declared res. Returns () when clean. This is the whole checker.

; ----------------------------------------------------------------------------
; ACCEPTANCE -- the two demos that are the go/no-go. Phase 0 is DONE when these
; two hold on a real (if tiny) domain, run under `make test` as asserts.
; ----------------------------------------------------------------------------
; (1) ERASURE (must be BIT-IDENTICAL):
;         (= (base-ev PROG) (base-ev (with-overlay units sigs PROG)))
;     i.e. attaching the overlay changes NOTHING the program computes. With dies
;     as static labels this is structural (eval never sees units/sigs), but the
;     assert PINS it so a future runtime-coin unification can't silently break it.
;
; (2) REJECTION (through the harness, with a location):
;         (! (check units sigs GOOD))        ; well-typed -> no clashes
;         (member? 'bad (map cap (check units sigs BAD)))   ; meters+seconds flagged, names `bad`
;     and crucially BAD still RUNS (erasure holds for ill-typed code too -- the
;     overlay rejects, it does not crash the program).
;
; A THIRD, cheap and worth it: the OPAQUE die = black_box. Show that a value whose
; sig is the domain top ("assume nothing") is never flagged and never enables a
; devirt -- i.e. black_box falls out as the top element, no special form. This
; closes the loop with the escape-hatch question that started all this.

; ----------------------------------------------------------------------------
; MILESTONES (~2-3 focused sessions)
; ----------------------------------------------------------------------------
;   M0  Copy kinds.l -> overlay engine; lift `dom` to a parameter; re-green its 4
;       demos through the generic version (proves the lift is behavior-preserving).
;   M1  Add the sig-table + boundary rule (typed callee uses its sig; untyped ->
;       top). Wire the fixpoint through monofix instead of kinds.l's hand `fix`.
;   M2  The units domain + the two acceptance demos (erasure, rejection) as asserts;
;       the black_box=top demo. Hook `check` at the wev/opfix seam as observe-only
;       (returns the form unchanged + a report to `out`/a handler).
;   M3  Write up findings in memory (does the seam hold? cost of erasure? where the
;       ergonomics pinch?) and decide go/no-go on Phase 1.

; ----------------------------------------------------------------------------
; RISKS / OPEN QUESTIONS (what could move the estimate)
; ----------------------------------------------------------------------------
;   * The boundary story: Phase 0 declares a sig per typed function and infers
;     bodies. Polymorphism (a die-variable, `room-area : (u u) -> u*u`) is Phase 1;
;     Phase 0 stays MONOMORPHIC to keep the seam small. Confirm that's enough to
;     be convincing.
;   * Where exactly `check` hooks and how it REPORTS without altering the pipeline
;     (observe-only). The wev seam returns source; the report must ride beside it
;     (a handler, like `help`, or a side channel), not mutate the form.
;   * "Clash" vs the domain's `top`: kinds.l uses `top` for "give up / generic".
;     A user domain needs to distinguish "unknown-but-fine" (top) from "provably
;     wrong" (a clash). Phase 0 units collapses them (unequal -> top = clash);
;     a real domain wants a separate bottom-of-badness. Decide if Phase 0 needs it.
;   * monofix expects a size/step shape; confirm the env-as-assoc fits, or keep
;     kinds.l's hand `fix` for the spike and unify onto monofix at M1 only if clean.
;
; ----------------------------------------------------------------------------
; DELIBERATELY EXCLUDED from Phase 0 (so the spike stays a spike)
; ----------------------------------------------------------------------------
;   - Dependent types / uu (that IS Phase 2; Phase 0 proves the seam uu will ride).
;   - The runtime-coin face of a die (Phase 1+; keep dies static for clean erasure).
;   - Polymorphism / die-variables (Phase 1).
;   - Multiple simultaneous overlays, subtyping beyond a join-lattice, inference
;     across module boundaries.

; ============================================================================
; M0 -- the domain-generic engine (kinds.l, with `dom` lifted to a parameter).
; The KINDS domain below is exactly doc/proto/kinds.l's hardwired lattice, now
; PASSED IN as a value; the engine reproduces kinds.l's four inferences, proving
; the lift is behaviour-preserving. `dom` is a map (a lookup fn): (dom 'join) etc.
; Run: out/host/ai doc/proto/overlay.l  (prints ok/FAIL per binding + a summary).
; ============================================================================
(: ; --- the KINDS domain, as a value (reproduces kinds.l) ---
   (rank k)  (? (id? k 'bot) 0 (id? k 'charm) 1 (id? k 'whole) 2 (id? k 'real) 3 (id? k 'cplx) 4 (id? k 'top) 5 -1)
   (num? k)  (: r (rank k) (&& (< 0 r) (< r 5)))                 ; charm..cplx = the numeric lane
   (joink a b) (? (id? a 'bot) b (id? b 'bot) a (id? a b) a
                 (&& (num? a) (num? b)) (? (< (rank a) (rank b)) b a)
                 'top)
   (tnumk a b) (? (|| (id? a 'bot) (id? b 'bot)) 'bot
                 (&& (num? a) (num? b)) (: j (joink a b) (? (id? j 'charm) 'whole j))   ; +/* may overflow charm
                 'top)
   (litk e)  (? (charm? e) 'charm (string? e) 'str 'top)
   kdom  #('join joink  'tr (\ op a b (tnumk a b))  'litdie litk  'dice '(bot charm whole real cplx top str))

   ; --- the generic engine: kinds.l's fix/kindof, now parameterised on `dom` ---
   (look env x)        (? (atom? env) 'bot (: p (cap env) (? (id? x (cap p)) (cup p) (look (cup env) x))))
   (joininto dom env x k) (link (link x ((dom 'join) (look env x) k)) env)              ; monotone shadow-update
   (kindof dom env e)  (? (nom? e)  (look env e)
                          (atom? e) ((dom 'litdie) e)                                    ; litdie handles every atom
                          (: h (cap e) as (map (\ s (kindof dom env s)) (cup e))
                             (? (member? h '(+ *)) ((dom 'tr) h (cap as) (cap (cup as)))
                                (&& (id? h '?) (= 4 (tally e))) ((dom 'join) (cap (cup as)) (cap (cup (cup as))))  ; (? c a b) -> join branches
                                'top)))
   (pairs bs)   (? (atom? bs) 0 (atom? (cup bs)) 0 (link (link (cap bs) (cap (cup bs))) (pairs (cup (cup bs)))))
   (alle a b)   (? (atom? a) 1 (: p (cap a) (&& (id? (cup p) (look b (cap p))) (alle (cup a) b))))
   (enveq a b)  (&& (alle a b) (alle b a))
   (step dom ps env) (foldl (\ env p (joininto dom env (cap p) (kindof dom env (cup p)))) env ps)
   (fix dom ps env)  (: e2 (step dom ps env) (? (enveq env e2) env (fix dom ps e2)))
   (infer dom bs)    (fix dom (pairs bs) 0)

   ; --- self-check: reproduce kinds.l's four inferences through the generic engine ---
   fails (tablet 0)
   (chk lbl exp act) (? (id? exp act) (: _ (puts "  ok   ") _ (puts lbl) (putc 10))
                        (: _ (pin fails 0 (+ 1 (peep fails 0 0))) _ (puts "  FAIL ") _ (puts lbl)
                           _ (puts ": exp ") _ (puts (string exp)) _ (puts " got ") _ (puts (string act)) (putc 10)))
   _ (: e (infer kdom '(x 5 y (+ x 1) z (* y y)))                    ; A. linear chain -> charm, whole(overflow), whole
        (: _ (puts ";; A linear chain\n")
           _ (chk "x=charm" 'charm (look e 'x)) _ (chk "y=whole" 'whole (look e 'y)) _ (chk "z=whole" 'whole (look e 'z)) 0))
   _ (: e (infer kdom '(x (? cnd 5 x)))                              ; B. fixpoint: x = 5-or-itself -> charm
        (: _ (puts ";; B fixpoint join\n") _ (chk "x=charm" 'charm (look e 'x)) 0))
   _ (: e (infer kdom '(n 100 m (+ n n) p (* m m)))                  ; C. widening: charm climbs to whole
        (: _ (puts ";; C widening\n")
           _ (chk "n=charm" 'charm (look e 'n)) _ (chk "m=whole" 'whole (look e 'm)) _ (chk "p=whole" 'whole (look e 'p)) 0))
   _ (: e (infer kdom '(s "hi" t (+ s s)))                           ; D. non-numeric: + on str -> top (no devirt)
        (: _ (puts ";; D non-numeric\n")
           _ (chk "s=str" 'str (look e 's)) _ (chk "t=top" 'top (look e 't)) 0))
   n (peep fails 0 0)
   _ (: _ (putc 10) _ (puts (? (= n 0) ";; M0 PASS -- generic engine reproduces kinds.l\n" (+ ";; M0 FAIL: " (+ (string n) " mismatches\n")))))
   0)
