#include "../g/g.h"
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

// noinline this because it leaks a stack address
g_noinline uintptr_t g_clock(void) {
 struct timespec ts;
 int s = clock_gettime(CLOCK_MONOTONIC, &ts);
 return s ? 0 : ts.tv_sec  * 1e3 + ts.tv_nsec / 1e6; }

struct g*gputc(struct g*f, int c) {
  if (c == '\\' || c == '"') putc(c, stdout);
  putc(c, stdout);
  return f; }
struct g*ggetc(struct g*f) { return g_core_of(f)->b = getc(stdin), f; }
struct g* gungetc(struct g*f, int c) { return g_core_of(f)->b = ungetc(c, stdin), f; }
struct g* geof(struct g*f) { return g_core_of(f)->b = feof(stdin), f; }
struct g* gflush(struct g*f) { fflush(stdout); return f; }

int main(int argc, char const **argv) {
 putc('"', stdout);
 enum g_status s = g_fin(g_evals_(g_ini(),
  "(:(g x e)(: r(read e)(?(= e r)0(: _(? x (puts \" \"))_(. r)(g 1 e))))(g 0 (sym 0)))"));
 putc('"', stdout);
 putc('\n', stdout);
 fflush(stdout);
 return s; }
