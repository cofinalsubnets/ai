#include "i.h"

#define opf(nom, op) g_vm(nom) {\
 word a = getnum(Sp[0]), b = getnum(Sp[1]);\
 *++Sp = putnum(a op b);\
 return Ip++, Continue(); }
opf(g_vm_bsl, <<) opf(g_vm_bsr, >>)

// Truncation toward zero. Magnitudes above 2^63 are already
// integer-valued in double precision, so we leave them alone instead of
// risking an int64 overflow on the round-trip. NaN passes through.
static g_inline g_flo_t g_trunc(g_flo_t x) {
 if (x != x) return x;
 g_flo_t m = x < 0 ? -x : x;
 if (m > (g_flo_t) 9.22e18) return x;
 return (g_flo_t)(int64_t) x; }

// Float remainder via truncated quotient. Matches libm's fmod() for
// the cases we care about. When b == 0, x/b is ±inf or NaN, ±inf*0 is
// NaN, so the result is NaN — same as libm.
static g_inline g_flo_t g_fmod(g_flo_t a, g_flo_t b) {
 return a - g_trunc(a / b) * b; }

// Arithmetic is dispatched op-first: each operator is its own g_vm handler
// (g_vm_add ... g_vm_rem) carrying an inlined both-fixnum fast path, and
// tail-calls its own dedicated slow handler (g_vm_add_flo ...) only when an
// operand isn't a fixnum, an integer op overflows, or a division degenerates.
// This keeps the common integer case free of the indirect re-dispatch +
// noinline struct return + runtime op-switch the old generic dispatcher
// imposed, and the slow path statically specialized — no op-switch either.

// Slow path, one handler per operator: at least one operand is non-fixnum, or
// the fixnum op overflowed the tagged range / hit a /0 or INT_MIN/-1
// degenerate. Non-numeric operand → nil. Otherwise promote both to g_flo_t,
// compute `expr`, and box the f64 inline. g_vm (noinline) + reached only by
// tail call, so the per-op fast paths stay branch-light and TCO-clean (the
// &-escaping float box never touches them).
#define AVM_FLO(n, expr) static g_vm(g_vm_##n##_flo) { \
 word a = Sp[0], b = Sp[1]; \
 if (!(nump(a) || flop(a)) || !(nump(b) || flop(b))) \
  return *++Sp = nil, Ip++, Continue(); \
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a), \
         bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b), rd = (expr); \
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t); \
 Have(req); \
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO); \
 Hp += req; \
 flo_put(v->shape, rd); \
 return *++Sp = word(v), Ip++, Continue(); }
AVM_FLO(add,  ad + bd)
AVM_FLO(sub,  ad - bd)
AVM_FLO(mul,  ad * bd)
AVM_FLO(quot, ad / bd)         // ±inf or NaN on bd == 0
AVM_FLO(rem,  g_fmod(ad, bd))  // NaN on bd == 0

// arith builtins take an explicit stack address but
// empirically this is compiled away on both GCC and
// clang so TCO is preserved.
#define AVM_OVF(n, builtin) g_vm(g_vm_##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { intptr_t t; \
  if (!builtin((intptr_t) getnum(a), (intptr_t) getnum(b), &t) && \
      t >= (INTPTR_MIN >> 1) && t <= (INTPTR_MAX >> 1)) \
   return *++Sp = putnum(t), Ip++, Continue(); } \
 return Ap(g_vm_##n##_flo, f); }
AVM_OVF(add, __builtin_add_overflow)
AVM_OVF(sub, __builtin_sub_overflow)
AVM_OVF(mul, __builtin_mul_overflow)

#define AVM_DIV(n, c_op) g_vm(g_vm_##n) { \
 word a = Sp[0], b = Sp[1]; \
 if (nump(a) && nump(b)) { \
  intptr_t av = getnum(a), bv = getnum(b); \
  if (bv != 0 && !(av == INTPTR_MIN && bv == -1)) { \
   intptr_t t = av c_op bv; \
   if (t >= (INTPTR_MIN >> 1) && t <= (INTPTR_MAX >> 1)) \
    return *++Sp = putnum(t), Ip++, Continue(); } } \
 return Ap(g_vm_##n##_flo, f); }
AVM_DIV(quot, /)
AVM_DIV(rem, %)

// Mixed-numeric ordered comparison, split like the arith handlers so the
// both-fixnum case is a compact, contiguous fast path: load/test/compare/
// store/jmp in source order, landing in a single cache line. The widen-to-
// float branch is peeled into a per-op slow handler (nom##_flo) tail-called
// only when an operand isn't a fixnum. Non-numeric operands return nil
// (matches existing degraded behavior on cross-type compares but well-defined).
#define CMP_FLO(nom, c_op) static g_vm(nom##_flo) {                  \
 word a = Sp[0], b = Sp[1], x = nil;                                 \
 if ((nump(a) || flop(a)) && (nump(b) || flop(b))) {                 \
  g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),           \
          bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b);           \
  x = (ad c_op bd) ? putnum(-1) : nil; }                             \
 return *++Sp = x, Ip++, Continue(); }
#define CMP_OP(nom, c_op) CMP_FLO(nom, c_op) g_vm(nom) {             \
 word a = Sp[0], b = Sp[1];                                          \
 if (__builtin_expect(nump(a) && nump(b), 1))                        \
  return *++Sp = (a c_op b) ? putnum(-1) : nil, Ip++, Continue();    \
 return Ap(nom##_flo, f); }

CMP_OP(g_vm_lt, <) CMP_OP(g_vm_le, <=) CMP_OP(g_vm_gt, >) CMP_OP(g_vm_ge, >=)

op(g_vm_bnot, 1, ~Sp[0] | 1)
op(g_vm_band, 2, (Sp[0] & Sp[1]) | 1)
op(g_vm_bor, 2, (Sp[0] | Sp[1]) | 1)
op(g_vm_bxor, 2, (Sp[0] ^ Sp[1]) | 1)
op(g_vm_nump, 1, oddp(Sp[0]) ? putnum(-1) : nil)
op11(g_vm_nilp, nilp(Sp[0]) ? putnum(-1) : nil)

// Unary math bif: nump/flop arg → double via vec_data, call fn, allocate
// rank-0 f64 inline. Non-numeric arg → nil. TCO-clean (no & escapes).
static g_vm(g_vm_math1, g_flo_t (*fn)(g_flo_t)) {
 word a = Sp[0];
 if (!nump(a) && !flop(a)) return Sp[0] = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a), rd = fn(ad);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(v->shape, rd);
 return Sp[0] = word(v), Ip++, Continue(); }

static g_vm(g_vm_math2, g_flo_t (*fn)(g_flo_t, g_flo_t)) {
 word a = Sp[0], b = Sp[1];
 if ((!nump(a) && !flop(a)) || (!nump(b) && !flop(b))) return
  *++Sp = nil, Ip++, Continue();
 g_flo_t ad = nump(a) ? (g_flo_t) getnum(a) : flo_get(a),
         bd = nump(b) ? (g_flo_t) getnum(b) : flo_get(b),
         rd = fn(ad, bd);
 uintptr_t req = Width(struct g_vec) + Width(g_flo_t);
 Have(req);
 struct g_vec *v = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(v->shape, rd);
 return *++Sp = word(v), Ip++, Continue(); }

#define mvm1(n) g_vm(g_vm_##n) { return Ap(g_vm_math1, f, g_##n); }
#define mvm2(n) g_vm(g_vm_##n) { return Ap(g_vm_math2, f, g_##n); }

// g_sin .. g_pow are macro aliases (g/g.h) for the C library math
// functions: libm on hosted builds, k/libc.c on the freestanding
// kernel. The op generators reference them through g_##n, which the
// preprocessor rescans into the real names after pasting.
#define m1(_) _(sin) _(cos) _(tan) _(atan) _(sqrt) _(exp) _(log)
#define m2(_) _(atan2) _(pow)
m1(mvm1) m2(mvm2)

op11(g_vm_flop, flop(Sp[0]) ? putnum(-1) : nil)
