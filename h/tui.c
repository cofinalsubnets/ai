// h/tui.c -- host front end: a line editor behind ggetc.
//
// ggetc IS the line editor. When its served line runs dry it raw-reads
// keystrokes, edits a line with the zipper editor (g_edit), renders it,
// and on Enter hands that line's characters (plus a newline) back one at
// a time. So the `read`/`getc` builtins -- and the REPL script h/repl.g
// running on top of them -- get line-edited input transparently, with no
// REPL logic hardcoded here. ggetc returns struct g* because the editing
// allocates and may relocate the heap; the threaded I/O hooks make that
// safe.
//
// A non-tty stdin (pipe/file) bypasses the editor -- ggetc just raw-reads
// bytes -- so the same binary doubles as a batch interpreter.

#include "../g/g.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <time.h>

g_noinline uintptr_t g_clock(void) {
  struct timespec ts;
  return clock_gettime(CLOCK_REALTIME, &ts) ? (uintptr_t) -1
       : (uintptr_t) (ts.tv_sec * 1000 + ts.tv_nsec / 1000000); }

struct g *gputc(struct g *f, int c) { return putchar(c), f; }
struct g *gflush(struct g *f)       { return fflush(stdout), f; }

// --- raw terminal mode -----------------------------------------------
static struct termios saved_termios;
static void restore_termios(void) {
  tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios); }

static void raw_mode(void) {
  tcgetattr(STDIN_FILENO, &saved_termios);
  atexit(restore_termios);                 // restore on normal exit
  struct termios raw = saved_termios;
  raw.c_lflag &= ~(ICANON | ECHO | ISIG | IEXTEN);  // no line buffering/echo
  raw.c_iflag &= ~(IXON | ICRNL | BRKINT | INPCK | ISTRIP);
  raw.c_cc[VMIN] = 1;                      // block for one byte
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSANOW, &raw); }
  // c_oflag is left alone, so '\n' on output still becomes CR-LF.

// --- keystroke decoding ----------------------------------------------
#define EV_QUIT  (-100)
#define EV_ENTER (-101)

static int rb(void) {                      // read one raw byte; -1 at EOF
  unsigned char c;
  return read(STDIN_FILENO, &c, 1) == 1 ? c : -1; }

// decode one keystroke into a g_edit_ev, a character (> 0), 0 to ignore,
// EV_ENTER (submit) or EV_QUIT (^D / EOF). a bare ESC blocks for the next
// key -- fine here; Ctrl-D is the reliable quit.
static int read_event(void) {
  int c = rb();
  switch (c) {
    case -1: case 4:           return EV_QUIT;
    case '\r': case '\n':      return EV_ENTER;
    case 8: case 127:          return g_ed_bsp;    // Backspace
    case 1:                    return g_ed_home;   // Ctrl-A
    case 5:                    return g_ed_end;    // Ctrl-E
    case 27:                                       // ESC: an escape seq
      if (rb() != '[') return 0;
      switch (c = rb()) {
        case 'D': return g_ed_left;
        case 'C': return g_ed_right;
        case 'A': return g_ed_up;
        case 'B': return g_ed_down;
        case 'H': return g_ed_home;
        case 'F': return g_ed_end;
        case '1': case '7': return rb(), g_ed_home;
        case '4': case '8': return rb(), g_ed_end;
        case '3':           return rb(), g_ed_del;
        default:            return 0; }
    default:
      return c >= ' ' && c < 127 ? c : 0; } }

// --- the line editor (behind ggetc) ----------------------------------
#define BUF 4096
static char   ln[BUF];     // the edited line currently being served
static size_t lnpos, lnlen;
static bool   in_eof;      // ^D pressed, or stdin ended
static int    pushback = -1;  // one-slot ungetc pushback (both paths)
static int    rendered;    // terminal cursor column relative to the start
                           // of the edit region (just after the prompt)

// redraw the edit line in place. all motion is relative to the region
// start, so it never disturbs whatever prompt precedes it on the line.
static void render(struct g *f) {
  char buf[BUF];
  size_t cur, n = g_edit_text(f, buf, BUF, &cur);
  if (n > BUF) n = BUF;
  if (rendered) printf("\x1b[%dD", rendered);   // back to the region start
  fputs("\x1b[K", stdout);                      // clear to end of line
  for (size_t i = 0; i < n; i++)
    putchar(buf[i] >= ' ' && buf[i] < 127 ? buf[i] : ' ');
  if (n > cur) printf("\x1b[%zuD", n - cur);    // cursor back to its offset
  rendered = cur;
  fflush(stdout); }

// edit one line: a keystroke loop until Enter (or ^D). on return the
// editor buffer (f->edl/f->edr) holds the line. threads f -- g_edit
// allocates and the collection it may trigger relocates the runtime.
static struct g *edit_line(struct g *f) {
  rendered = 0;                            // cursor sits at the region start
  for (;;) {
    render(f);
    int ev = read_event();
    if (ev == EV_QUIT)  return in_eof = true, f;
    if (ev == EV_ENTER) return putchar('\n'), fflush(stdout), f;
    if (!g_ok(f = g_edit(f, ev))) return f; } }

// --- host input hooks ------------------------------------------------
// ggetc serves the next input character. interactively it runs the line
// editor to refill once a line is used up; otherwise it raw-reads stdin.
struct g *ggetc(struct g *f) {
  if (pushback >= 0)                             // a previously ungot char
    return f->b = pushback, pushback = -1, f;
  if (!isatty(STDIN_FILENO)) {                   // non-tty: raw bytes
    int c = rb();
    return f->b = c, in_eof = c < 0, f; }
  if (lnpos < lnlen) return f->b = (unsigned char) ln[lnpos++], f;
  if (in_eof) return f->b = EOF, f;
  f = edit_line(f);                              // -> f->edl/f->edr hold a line
  if (!g_ok(f)) return f;
  if (in_eof) return f->b = EOF, f;              // ^D ended the session
  lnlen = g_edit_text(f, ln, BUF - 1, NULL);     // flatten the line out
  if (lnlen > BUF - 1) lnlen = BUF - 1;
  ln[lnlen++] = '\n';                            // terminate the served line
  lnpos = 0;
  f->edl = f->edr = g_nil;                       // clear the editor
  return f->b = (unsigned char) ln[lnpos++], f; }

struct g *gungetc(struct g *f, int c) {
  return pushback = c, f; }

struct g *geof(struct g *f) {
  return f->b = in_eof, f; }

// --- main: load the prelude and run the REPL script ------------------
int main(int argc, char const **argv) {
  if (isatty(STDIN_FILENO)) raw_mode();
  struct g *f;
  for (f = g_ini(); *argv; f = g_strof(f, *argv++));
  for (f = g_push(f, 1, g_nil); argc--; f = gxr(f));
  if (g_ok(f)) {
    struct g_def d[] = {{"argv", g_pop1(f)}, {0}};
    static char const boot[] =
#include "boot.h"
    ;
    static char const repl[] =
#include "repl.h"
    ;
    f = g_evals_(g_defs(f, d), boot);            // the prelude
    f = g_evals_(f, repl); }                     // h/repl.g drives the REPL
  enum g_status s = g_code_of(f);
  g_fin(f);
  return s; }
