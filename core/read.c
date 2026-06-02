#include "i.h"

static struct g *grbufg(struct g *f, uintptr_t len);
static struct g *flo_alloc(struct g*, g_flo_t);
static struct g *gzreads(struct g *f, bool nested);
static struct g *gzread1(struct g *f);
static g_inline struct g *gzread1sym(struct g*f, int c);
static g_inline struct g *gzread1str(struct g*f);

////
/// " the parser "
//
//
// get the next significant character from the stream. MM-protect the C
// `i` parameter across the multiple port_* calls — each push triggers a
// have() check that may GC and move heap ports.

static struct g* g_z_getc(struct g*f) {
 while (g_ok(f = zgetc(f))) switch (f->b) {
  default: return f;
  case '#': case ';':
   while (g_ok(f = zeof(f)) && !f->b && g_ok(f = zgetc(f)) && f->b != '\n' && f->b != '\r');
  case 0: case ' ': case '\t': case '\n': case '\r': case '\f':
   continue; }
 return f; }

static struct g *gzread1(struct g*f) {
 if (!g_ok(f = g_z_getc(f))) return f;
 switch (f->b) {
  case '(':  return gzreads(f, true);
  case ')': case EOF: return encode(f, g_status_eof);
  case '\'': return
   g_code_of(f = gzread1(f)) == g_status_eof ? // quote with no operand
    encode(g_core_of(f), g_status_more) :
    gxl(pushq(gxr(push0(f))));
  case '"': return gzread1str(f);
  default: return gzread1sym(f, f->b); } }

static struct g *gzreads(struct g *f, bool nested) {
 intptr_t n = 0;
 for (int c; g_ok(f = g_z_getc(f)); n++) {
  if ((c = f->b) == ')') break;                          // list closed
  if (c == EOF) {                               // end of input...
   if (nested) return encode(f, g_status_more); 
   break; }                                     //  ...at top level: done
  f = gzread1(zungetc(f, c)); }
 for (f = push0(f); n--; f = gxr(f));
 return f; }

static g_inline struct g *gzread1str(struct g*f) {
 int c;
 size_t n = 0, lim = sizeof(word);
 struct g_str *b = 0;
 MM(f, (g_word*) &b);
 for (f = str0(f, sizeof(word)); g_ok(f); f = grbufg(f, lim), lim *= 2)
  for (b = (struct g_str*) f->sp[0]; n < lim; txt(b)[n++] = c) {
   if (!g_ok(f = zgetc(f))) goto out;     // threaded; char in f->b
   else if ((c = f->b) == '"') { len(b) = n; goto out; }
   else if (c == EOF) { f = encode(f, g_status_more); goto out; }
   else if (c == '\\') {                               // escape: take next char
    if (!g_ok(f = zgetc(f))) goto out;
    else if ((c = f->b) == EOF) { f = encode(f, g_status_more); goto out; }
    else if (c == 'n') c = '\n';
    else if (c == 't') c = '\t';
    else if (c == 'r') c = '\r';
    else if (c == '0') c = '\0';
    else if (c == 'x') {                          // \xHH: two hex digits
     if (!g_ok(f = zgetc(f))) goto out;
     int h1 = f->b;
     if (h1 == EOF) { f = encode(f, g_status_more); goto out; }
     if (!g_ok(f = zgetc(f))) goto out;
     int h2 = f->b;
     if (h2 == EOF) { f = encode(f, g_status_more); goto out; }
     int v1 = h1 <= '9' ? h1 - '0' : (h1 | 0x20) - 'a' + 10;
     int v2 = h2 <= '9' ? h2 - '0' : (h2 | 0x20) - 'a' + 10;
     c = ((v1 & 0xf) << 4) | (v2 & 0xf); } } }
out: return UM(f), f; }

static g_inline struct g *gzread1sym(struct g*f, int c) {
 uintptr_t n = 1, lim = sizeof(intptr_t);
 struct g_str *b = 0;
 MM(f, (g_word*) &b);
 if (g_ok(f = str0(f, sizeof(word))))
  for (txt((struct g_str*) f->sp[0])[0] = c; g_ok(f); f = grbufg(f, lim), lim *= 2)
   for (b = (struct g_str*) f->sp[0]; n < lim; txt(b)[n++] = c) {
    if (!g_ok(f = zgetc(f))) goto out;
    switch (c = f->b) {
     default: continue;
     case ' ': case '\n': case '\t': case '\r': case '\f': case ';': case '#':
     case '(': case ')': case '"': case '\'': case 0 : case EOF:
      if (!g_ok(f = zungetc(f, c))) goto out;
      b = (struct g_str*) f->sp[0];
      len(b) = n;
      txt(b)[n] = 0; // zero terminate for strtol ; n < lim so this is safe
      char *e;
      long j = strtol(txt(b), &e, 0);
      if (*e == 0) f->sp[0] = putnum(j);
      else {
       double d = strtod(txt(b), &e);
       if (e == txt(b) || *e != 0) f = intern(f);
       else if (g_ok(f = flo_alloc(f, d))) f->sp[1] = f->sp[0], f->sp++; }
      goto out; } }
out: return UM(f), f; }
// Allocate a rank-0 G_VT_FLO g_vec wrapping v, push on Sp.
static g_inline struct g *flo_alloc(struct g *f, g_flo_t v) {
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 if (g_ok(f = g_have(f, req + 1))) {
  struct g_vec *r = ini_scalar(bump(f, req), G_VT_FLO);
  flo_put(r->shape, v);
  *--f->sp = word(r); }
 return f; }

struct g *g_reads(struct g *f, struct g_io* i) {
 return g_core_of(f)->io = i, gzreads(f, false); }

static struct g *g_read(struct g *f, struct g_io *i) {
 uintptr_t depth = ((word*) f + f->len) - f->sp;
 if (!g_ok(f = g_read1(f, i))) {
  struct g *c = g_core_of(f); // reset stack on parse fail
  c->sp = (word*) c + c->len - depth; }
 return f; }

// Strict parse of a gwen-string's bytes as a decimal float. g_noinline +
// by-value struct return so the &e and &buf escapes stay inside this
// frame and never reach g_vm_flo, which needs to TCO out via Continue().
struct g_strtod_r { double d; bool ok; };
static g_noinline struct g_strtod_r parse_flo_strict(char const *bytes, size_t len) {
 struct g_strtod_r r = { 0, false };
 char buf[64], *e;
 if (len != 0 && len < sizeof buf)
  memcpy(buf, bytes, len),
  buf[len] = 0,
  r.d = strtod(buf, &e),
  r.ok = e != buf && *e == 0;
 return r; }

struct g *g_read1(struct g*f, struct g_io *i) {
 return g_core_of(f)->io = i, gzread1(f); }

static struct g *grbufg(struct g *f, uintptr_t len) {
 if (g_ok(f = str0(f, 2 * len)))
  memcpy(txt(f->sp[0]), txt(f->sp[1]), len),
  f->sp[1] = f->sp[0],
  f->sp++;
 return f; }

// (flo s) — parse a gwen string as a decimal float. Returns a rank-0
// f64 box if the entire string parses, else nil. Used by the gwen-side
// reader in repl.g to match the C reader's strtol → strtod → intern
// cascade on float-shaped tokens.
g_vm(g_vm_flo) {
 word x = Sp[0];
 if (!strp(x)) return Sp[0] = nil, Ip += 1, Continue();
 struct g_strtod_r p = parse_flo_strict(str(x)->bytes, str(x)->len);
 if (!p.ok) return Sp[0] = nil, Ip += 1, Continue();
 uintptr_t req = b2w(sizeof(struct g_vec) + sizeof(g_flo_t));
 Have(req);
 struct g_vec *r = ini_scalar((struct g_vec*) Hp, G_VT_FLO);
 Hp += req;
 flo_put(r->shape, (g_flo_t) p.d);
 Sp[0] = word(r);
 return Ip++, Continue(); }

g_vm(g_vm_fread) {
 Ip++;
 if (!iop(Sp[0])) return Sp++, Continue();
 struct g_io *i = (struct g_io*) Sp[0];
 Pack(f);
 if (g_ok(f = g_read(f, i))) f->sp[2] = f->sp[0], f->sp += 2;
 else switch (g_code_of(f)) {
  case g_status_eof:
   f = g_core_of(f);
   f->sp++;
   break;
  case g_status_more:
   f = g_core_of(f);
   f->sp[1] = f->sp[0];
   f->sp++;
   break;
  default: return gtrap(f); }
 return Unpack(f), Continue(); }

g_vm(g_vm_str) {
 uintptr_t n = llen(Sp[0]);
 // FIXME use Have instead of Pack/Unpack
 Pack(f);
 if (!g_ok(f = str0(f, n))) return gtrap(f);
 // sp[0] is the new string; sp[1] is the original charlist.
 char *t = txt(f->sp[0]);
 uintptr_t i = 0;
 for (word l = f->sp[1]; twop(l); l = B(l)) t[i++] = (char) getnum(A(l));
 f->sp[1] = f->sp[0];
 f->sp += 1;
 Unpack(f);
 Ip += 1;
 return Continue(); }
