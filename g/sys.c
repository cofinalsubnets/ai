#include "i.h"

op11(g_vm_clock, putnum(g_clock() - getnum(Sp[0])))

g_vm(g_vm_info) {
 size_t const req = 4 * Width(struct g_pair);
 Have(req);
 struct g_pair *si = (struct g_pair*) Hp;
 Hp += req;
 Sp[0] = word(si);
 ini_two(si, putnum(f), word(si + 1));
 ini_two(si + 1, putnum(f->len), word(si + 2));
 ini_two(si + 2, putnum(Hp - ptr(f)), word(si + 3));
 ini_two(si + 3, putnum(ptr(f) + f->len - Sp), nil);
 Ip += 1;
 return Continue(); }

