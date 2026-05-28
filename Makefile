# Project root. This file defines the cross-cutting phony tasks (h, k,
# pd, test, clean, install, ...) and delegates the actual build logic
# to per-subfolder Makefiles (h/, k/, pd/). Shared variables live in
# common.mk.
R := .
include common.mk

.PHONY: test all h k pd clean distclean
test: h
	@echo TEST
	@cat $t | $m
all: h k pd
h:
	@$(MAKE) -C h
k:
	@$(MAKE) -C k
pd:
	@$(MAKE) -C pd
clean:
	rm -rf b `git check-ignore esp/* wasm/* pico/*`
distclean: clean
	rm -rf dl

# Host artefacts produced by `make -C h`. Declaring them as targets that
# depend on the phony `h` means any other rule that consumes them (the
# install rules, valg, perf, etc.) triggers a single recursive `make -C
# h` rather than failing with "no rule to make target".
b/h/$n b/h/$n.1 b/h/lib$n.a b/h/lib$n.so: h

.PHONY: valg perf repl cloc cat
valg: h
	cat $t | valgrind --error-exitcode=1 $m
b/perf.data: h
	cat $t | perf record -o $@ $m
perf: b/perf.data
	perf report -i $<
b/flamegraph.svg: b/perf.data
	flamegraph -o $@ --perfdata $<
repl: h
	@$m
cloc:
	cloc --by-file --force-lang=Lisp,$x g h js k p pd t vim
cat: clean all test

.PHONY: disasm gdb
disasm: h
	rizin -A $m
gdb: h
	gdb $m

# Pass-throughs for the kernel-specific phonies that need k_qemu etc.
.PHONY: run run-hdd run-headless run-efi run-efi-headless
run run-hdd run-headless run-efi run-efi-headless:
	$(MAKE) -C k $@

# Pass-through for the playdate simulator.
.PHONY: sim
sim:
	$(MAKE) -C pd sim

# --- install / uninstall --------------------------------------------
PREFIX ?= .local/
VIMPREFIX ?= .vim/
DESTDIR ?= $(HOME)/
d = $(DESTDIR)/$(PREFIX)
v = $(DESTDIR)/$(VIMPREFIX)
installs = \
  $d/bin/$n \
  $d/bin/$nsh \
  $d/g/man/man1/$n.1 \
  $d/lib/$n/boot.$x \
  $d/lib/$n/repl.$x \
  $d/lib/lib$n.a \
  $d/lib/lib$n.so \
  $d/include/$x.h \
  $v/ftdetect/$n.vim \
  $v/syntax/$n.vim \
  $v/ftplugin/$n.vim

.PHONY: install uninstall
install: $(installs)
uninstall:
	@echo RM	$(abspath $(installs))
	@rm -f $(installs)

$d/include/$x.h: g/$x.h
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/boot.$x: g/boot.g
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/$n/%.$x: h/%.$x
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.a: b/h/lib$n.a
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$d/lib/lib$n.so: b/h/lib$n.so
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$n: b/h/$n
	@echo CP	$(abspath $@)
	@install -D -m 755 -s $< $@

$d/bin/$nsh: h/$nsh
	@echo CP	$(abspath $@)
	@install -D -m 755 $< $@

$d/g/man/man1/$n.1: b/h/$n.1
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftdetect/$n.vim: vim/ftdetect.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/syntax/$n.vim: vim/syntax.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@

$v/ftplugin/$n.vim: vim/ftplugin.vim
	@echo CP	$(abspath $@)
	@install -D -m 644 $< $@
