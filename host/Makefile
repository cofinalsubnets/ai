# Host build. Run from project root via `make h`, or directly via
# `cd h && make`. Outputs (binary, libs, manpage, the bootstrap gl0, and the
# gl0-generated boot.h / repl.h / data_vt.h) all land in $(R)/h/b/.
R := ..
include $(R)/common.mk

h_o = $(g_c:$(R)/%.c=b/%.o)
# -Ib is first so b/data_vt.h (generated below) shadows the portable
# g/data_vt.h; nothing else in b/ collides with a g/ header.
cc = $(CC) $(g_cflags) -fpic -Ib -I$(R) -I$(R)/core -I.
# Pins the gwen_data_vt sentinel order on every final link (see the script).
vt_ld = $(R)/core/gwen_data_vt.ld
ldflags = -Wl,-T,$(vt_ld)
# data.o is the data-sentinel TU (g/data.c). tools/gen_data_vt.g reflects its
# gwen_data_vt.NN section sizes into b/data_vt.h, whose g_typ() shifts instead
# of doing the portable header's two link-time divides. Every object depends
# on it (below) except data.o itself, which bootstraps from g/data_vt.h -- it
# never calls g_typ, so the stride it records doesn't depend on which it sees.
vt_h = b/data_vt.h
# Prelude-less bootstrap interpreter, one-shot compiled against the fallback
# core/data_vt.h (no -Ib), used to run the gwen build tools (tools/*.g) that
# generate the headers below -- so it needs none of those headers itself,
# breaking the circularity. Gets its prelude at runtime via the cli -l flag.
gl0 = b/gl0

.PHONY: default boot.h repl.h clean
default: b/$n b/lib$n.so b/$n.1

# Phony aliases so kernel/playdate builds can request the generated
# headers via `make -C ../h boot.h` / `repl.h`.
boot.h: b/boot.h
repl.h: b/repl.h

clean:
	rm -rf b

b/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@ar rcs $@ $^

b/lib$n.so: b/lib$n.a $(vt_ld)
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(cc) $(ldflags) -shared -o $@ -Wl,--whole-archive b/lib$n.a -Wl,--no-whole-archive -lm

# The data-sentinel TU bootstraps from the portable header (no b/data_vt.h
# prerequisite -- that would be circular, since b/data_vt.h is reflected out
# of this object). Its explicit recipe overrides the pattern rules below.
b/core/data.o: $(R)/core/data.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

# One-shot bootstrap interpreter (fallback header, no compiled-in prelude).
$(gl0): main.c $(g_c) $(g_h) $(vt_ld)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(CC) $(g_cflags) -DGL_BOOTSTRAP -I$(R) -I$(R)/core -I. $(ldflags) -o $@ main.c $(g_c) -lm

b/data_vt.h: b/core/data.o $(gl0) $(R)/tools/gen_data_vt.$x $(R)/core/boot.$x
	@echo GEN	$@
	@$(gl0) -l $(R)/core/boot.$x $(R)/tools/gen_data_vt.$x $< -o $@

# g/*.c (and any other root-level *.c) -> b/<dir>/*.o
b/%.o: $(R)/%.c $(g_h) $(vt_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

# local h/*.c -> b/*.o
b/%.o: %.c $(g_h) $(vt_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

b/$n: main.c b/lib$n.a b/boot.h b/repl.h $(vt_h) $(vt_ld)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) $(ldflags) -o $@ main.c b/lib$n.a -lm

# boot.h / repl.h: the prelude re-serialized into a C string literal by
# tools/lcat.g (the gwen port of the old host/lcat.c), run on the bootstrap gl0.
# lcat.g is bif-only, so it needs no prelude loaded.
b/repl.h: $(gl0) $(R)/tools/lcat.$x $(R)/core/repl.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(gl0) $(R)/tools/lcat.$x $(R)/core/repl.$x >$@

b/boot.h: $(gl0) $(R)/tools/lcat.$x $(R)/core/boot.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@$(gl0) $(R)/tools/lcat.$x $(R)/core/boot.$x >$@

b/$n.1: b/$n manpage.$x
	@echo GEN	$@
	@$m < manpage.$x > $@
