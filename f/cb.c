#include "g.h"
#include "cb.h"

void cb_fill(struct cb *c, uint8_t _) {
  uint32_t cell = cb_cell(_, c->cur_fg, c->cur_bg, c->cur_font);
  for (uint32_t i = 0, j = c->rows * c->cols; i < j; i++)
    c->cb[i] = cell; }

void cb_clear(struct cb *c) { cb_fill(c, 0); }

void cb_cur(struct cb *c, uint32_t row, uint32_t col) {
  c->wpos = (row * c->cols + col) % (c->rows * c->cols); }

void cb_attr(struct cb *c, uint8_t fg, uint8_t bg, uint8_t font) {
  c->cur_fg = fg, c->cur_bg = bg, c->cur_font = font; }

static void cb_line_feed(struct cb *c) {
  uintptr_t rs = c->rows, cs = c->cols,
            p = 1 + c->wpos / cs;
  c->wpos = cs * (p == rs ? 0 : p); }

void cb_putc(struct cb *c, char i) {
  if (i == '\b') {
    if (c->wpos != c->rpos) c->wpos--;
    return; }
  c->cb[c->wpos] = cb_cell(i, c->cur_fg, c->cur_bg, c->cur_font);
  if (i == '\n') return cb_line_feed(c);
  if (++c->wpos == c->cols * c->rows) c->wpos = 0; }

int cb_ungetc(struct cb *c, int i) {
  uint16_t r = c->rpos;
  r = r > 0 ? r - 1 : c->cols * c->rows - 1;
  if (r == c->wpos) return -1;
  c->rpos = r;
  // rewind one cell and replace its char, keeping the cell's colour/font
  c->cb[r] = (c->cb[r] & ~(uint32_t) 0xff) | (uint8_t) i;
  return i; }

int cb_eof(struct cb *c) {
  return c->rpos == c->wpos; }

int cb_getc(struct cb *c) {
  if (c->rpos == c->wpos) return -1;
  int i = cb_ch(c->cb[c->rpos]);
  if (++c->rpos == c->cols * c->rows) c->rpos = 0;
  return i; }
