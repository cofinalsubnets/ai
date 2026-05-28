# Host build. Run from project root via `make h`, or directly via
# `cd h && make`. Outputs land in $(R)/b/h/ and the lcat-generated
# headers boot.h/repl.h land in $(R)/b/ (shared with k/ and pd/).
R := ..
include $(R)/common.mk

h_o = $(g_c:$(R)/%.c=$(R)/b/h/%.o)
cc = $(CC) $(g_cflags) -fpic -I$(R) -I$(R)/g -I. -I$(R)/b

.PHONY: default boot.h repl.h
default: $(R)/b/h/$n $(R)/b/h/lib$n.so $(R)/b/h/$n.1

# Phony aliases so kernel/playdate builds can request the generated
# headers via `make -C ../h boot.h` / `repl.h`.
boot.h: $(R)/b/boot.h
repl.h: $(R)/b/repl.h

$(R)/b/h/lib$n.a: $(h_o)
	@echo AR	$@
	@mkdir -p $(dir $@)
	@ar rcs $@ $^

$(R)/b/h/lib$n.so: $(R)/b/h/lib$n.a
	@echo LD	$@
	@mkdir -p $(dir $@)
	@$(cc) -shared -o $@ -Wl,--whole-archive $^ -Wl,--no-whole-archive

# g/*.c (and any other root-level *.c) -> b/h/<dir>/*.o
$(R)/b/h/%.o: $(R)/%.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c $< -o $@

# local h/*.c -> b/h/*.o
$(R)/b/h/%.o: %.c $(g_h)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -c -I$(R)/b/h $< -o $@

$(R)/b/h/$n: main.c $(R)/b/h/lib$n.a $(R)/b/boot.h $(R)/b/repl.h
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -o $@ main.c $(R)/b/h/lib$n.a -lm

$(R)/b/h/lcat: lcat.c $(h_o)
	@echo CC	$@
	@mkdir -p $(dir $@)
	@$(cc) -o $@ $^

$(R)/b/repl.h: $(R)/b/h/lcat $(R)/$x/repl.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@cat $(R)/$x/repl.$x | $(R)/b/h/lcat >$@

$(R)/b/boot.h: $(R)/b/h/lcat $(R)/$x/boot.$x
	@echo GEN	$@
	@mkdir -p $(dir $@)
	@cat $(R)/$x/boot.$x | $(R)/b/h/lcat >$@

$(R)/b/h/$n.1: $(R)/b/h/$n manpage.$x
	@echo GEN	$@
	@$m < manpage.$x > $@
