#include "gwen.h"
#include <vt.h>

// Per-data-kind apply handler table, indexed by enum q. Each data sentinel
// (below) recovers its own kind via g_typ and tail-jumps through this table, so
// the kind's apply behavior lives in a slot rather than the sentinel body. Every
// data kind now has a meaningful apply (pair = eliminator, string/symbol = index,
// hash = lookup, the numeric tower = Church numeral); opaque handles that lack one
// (ports, buffers) behave as 0 via their own g_vm_* sentinel, not through here.

// (t x): applying a hash looks x up as a key, nil if absent -- i.e. the value
// is itself the lookup fn, so (t x) == (get 0 x t). g_hget doesn't allocate, so
// no GC dance; the frame unwinds exactly as self-quote (drop arg, jump to the
// return address held in Sp[1], leave the result on top).
static g_vm(data_hash_apply) {
 word v = g_hget(f, nil, Sp[0], hsh(Ip));
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// (s k): applying a string indexes it -- k is a byte offset and the result is
// the unsigned byte 0..255 there, 1 if k is non-numeric or out of range. The 1
// matches the empty string ("" == 0): a numeric ("" k) is Church-numeral k**0 ==
// 1. No allocation, so the frame unwinds like self-quote.
static g_vm(data_text_apply) {
 word k = Sp[0], v = g_putnum(1), n;
 if (oddp(k) && (n = g_getnum(k)) >= 0 && n < (word) len(Ip))
  v = g_putnum((unsigned char) txt(Ip)[n]);
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

// (y k): applying a symbol falls back to its underlying name string, so (y k) ==
// (nom k) -- the byte at offset k of the name (cf. data_text_apply). nom encodes
// the kind: a string is the name (interned), a symbol is the naming symbol of a
// named-uninterned sym (follow once to its string nom), 0 is an anonymous gensym
// with no name. With no underlying string we act the same as 0: an absent name is
// the empty string ("" == 0), whose every index is out of range -> 1.
static g_vm(data_sym_apply) {
 word nom = word(((struct g_atom*) Ip)->nom);
 if (nom && cell(nom)->ap == g_vm_sym)              // named-uninterned: follow to the naming symbol
  nom = word(((struct g_atom*) nom)->nom);
 if (nom && cell(nom)->ap == g_vm_text)             // interned/named: index the underlying name string
  return Ip = cell(nom), Ap(data_text_apply, f);
 return Ip = cell(*++Sp), *Sp = g_putnum(1), Continue(); }  // anonymous: no name -> act same as 0

// (n x): applying a number is Church-numeral application, just like a fixnum (cf.
// g_vm_numap). Fixnums reach num-ap via the odd-tag check in g_vm_ap; the rest of
// the tower (floats, wide-int boxes, complex, arrays -- all g_vm_vec -- and bignums)
// are heap pointers, so they arrive at their data sentinel instead. We lay the same
// [n, num-ap, x, ret] frame and run the shared numap_drive, handing the boxed
// operator n (in Ip) to the gwen num-ap handler, which picks exponentiate / compose /
// self by operand+operator kind. Mirrors g_vm_numap exactly (Have(2), grow by two).
static g_vm(data_num_apply) {
 Have(2);
 word n = word(Ip), x = Sp[0], ret = Sp[1], *dst = Sp - 2;
 dst[0] = n, dst[1] = g_numap, dst[2] = x, dst[3] = ret;
 return Sp = dst, Ip = numap_drive, Continue(); }

// ((a . b) f) == (f a b): a pair is its own Church eliminator (cons = \a b f.f a b).
// We re-enter the apply protocol via a static driver thread: lay the stack as the
// two curried calls expect, then [ap ; swap+ap ; ret0] runs ((f a) b) and returns
// the result to the caller. pair_swap reorders [result, b] -> [b, result] so the
// second ap sees arg=b, fn=(f a). The driver lives in .data, so the return
// addresses it leaves on the stack fall outside the GC pool and are never forwarded
// (cf. spawn_body); currying/arity are handled by the reused g_vm_ap/g_vm_cur path.
static g_vm(pair_swap) {
 word t = Sp[0]; Sp[0] = Sp[1], Sp[1] = t;
 return Ap(g_vm_ap, f); }
static union u pair_drive[] = { {g_vm_ap}, {.ap = pair_swap}, {.ap = g_vm_ret0} };
static g_vm(data_pair_apply) {
 Have(2);
 word a = A(Ip), b = B(Ip), fn = Sp[0];     // re-read after the Have guard; no alloc past here
 Sp -= 2;                                    // grow the frame to [a, fn, b, ret]
 Sp[0] = a, Sp[1] = fn, Sp[2] = b;           // Sp[3] = ret (was Sp[1]) stays put
 return Ip = pair_drive, Continue(); }

g_vm_t *g_data_ap[G_DATA_VT_N] = {
 [two_q]  = data_pair_apply, [vec_q]  = data_num_apply, [sym_q] = data_sym_apply,
 [hash_q]  = data_hash_apply,  [text_q] = data_text_apply, [big_q] = data_num_apply, };

#define data_vt(idx, name) \
 __attribute__((section("gwen_data_vt." #idx), used)) g_vm(name) { \
  return Ap(g_data_ap[g_typ(Ip)], f); }

#define go(_)\
  _(00, g_vm_two) _(01, g_vm_vec) _(02, g_vm_sym)\
  _(03, g_vm_hash) _(04, g_vm_text) _(05, g_vm_big)

go(data_vt)
