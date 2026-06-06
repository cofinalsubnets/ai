#include "i.h"

// Per-data-kind apply handler table, indexed by enum q. Each data sentinel
// (below) recovers its own kind via g_typ and tail-jumps through this table, so
// the kind's apply behavior lives in a slot rather than the sentinel body. Every
// slot starts as self-quote (a data value applied to itself returns itself, as
// before); individual kinds can later install a custom apply handler here.
static g_vm(data_self_quote) {
 word x = word(Ip);
 return Ip = cell(*++Sp), *Sp = x, Continue(); }

// (t x): applying a table looks x up as a key, nil if absent -- i.e. the value
// is itself the lookup fn, so (t x) == (get 0 x t). g_tget doesn't allocate, so
// no GC dance; the frame unwinds exactly as self-quote (drop arg, jump to the
// return address held in Sp[1], leave the result on top).
static g_vm(data_tbl_apply) {
 word v = g_tget(f, nil, Sp[0], tbl(Ip));
 return Ip = cell(*++Sp), *Sp = v, Continue(); }

g_vm_t *g_data_ap[G_DATA_VT_N] = {
 [two_q]  = data_self_quote, [vec_q]  = data_self_quote, [sym_q] = data_self_quote,
 [tbl_q]  = data_tbl_apply,  [text_q] = data_self_quote, [big_q] = data_self_quote, };

#define data_vt(idx, name) \
 __attribute__((section("gwen_data_vt." #idx), used)) g_vm(name) { \
  return Ap(g_data_ap[g_typ(Ip)], f); }

#define go(_)\
  _(00, g_vm_two) _(01, g_vm_vec) _(02, g_vm_sym)\
  _(03, g_vm_tbl) _(04, g_vm_text) _(05, g_vm_big)

go(data_vt)
