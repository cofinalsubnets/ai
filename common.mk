# Shared variables for the host and free (freestanding kernel) builds, and
# for out-of-tree ports (the l-ports repo). Each includer sets R to the
# relative path to the project root before including this file (the root
# Makefile sets R := .) so the paths below resolve from any cwd.
# Per-frontend build output lives under $R/out/<frontend>/.
R ?= .

m = $R/out/host$(hsuf)/ai
a ?= $(shell uname -m)

# clang is the default host/ai0 compiler (every dev machine here has it; mac's
# `cc` is clang anyway, and the kernel build already defaults KCC=clang). NB: a
# plain `CC ?= clang` is a no-op -- make ships a built-in default `CC = cc` (origin
# `default`, not `undefined`), so `?=` never fires. Override the built-in default
# explicitly while still honoring an env/CLI `CC=` (origin command line/environment):
# `make CC=gcc`. cc_user marks an explicit choice -- it opts out of the musl
# default below and the host block's musl-clang pick.
ifeq ($(origin CC),default)
CC = clang
else
cc_user := 1
endif

# The host binary's FLAVOR. STATIC=1 links `ai` fully static against musl (the
# STATIC block in the root Makefile has the whole story) -- and that IS the
# default on Linux when musl-clang is present and CC is untouched: the everyday
# binary is the portable one (+1% size, same speed, DNS intact). STATIC=0 forces
# the dynamic glibc build. The default flavor always owns the canonical out/host
# tree; the OTHER flavor gets its own suffixed tree (out/host-glibc here,
# out/host-musl on a machine without the musl default) so the two libcs never
# share objects -- and $m below follows, so tests run the flavor you asked for.
static_default := $(if $(cc_user),,$(if $(filter Linux,$(shell uname -s)),$(shell command -v musl-clang 2>/dev/null)))
STATIC ?= $(if $(static_default),1)
override STATIC := $(filter-out 0,$(STATIC))
hsuf := $(if $(STATIC),$(if $(static_default),,-musl),$(if $(static_default),-glibc,))

# ai_tco for the builds that can take it: 1 = the tail-threaded VM (aps tail-jump,
# never return -- `make vmret` verifies it per binary), 0 = the trampoline loop.
# The host runs $(tco). PINNED ELSEWHERE: ai0 stays 0 (the deliberate
# trampoline-coverage lane) and the kernel test build stays 0 (hangs at 1 --
# see the K_TEST block in the root Makefile).
tco ?= 1

# the corpus: 00-init's harness first, the spec second, then the rest. glaze-x86 is EXCLUDED:
# it needs emit.l/auto.l cat'd ahead of it and EXECUTES x86-64 native code, so it runs only under
# the x86-guarded `test_glaze`, never the arch-neutral corpus (which would crash on a non-x86 host).
t = $R/test/00-init.l $R/test/spec.l $(filter-out %/00-init.l %/spec.l %/glaze-x86.l,$(sort $(wildcard $R/test/*.l)))

ai_h = $(wildcard $R/*.h)
ai_c = $R/ai.c
f_c = $(wildcard $R/port/quay/*.c)
c_c = $(wildcard $R/libc/*.c)

# -std spelling: clang accepts `gnu23` only from ~clang 18 (Xcode 16). Older Apple
# clang on an old mac wants `gnu2x` (the pre-final spelling). Probe $(CC) once and
# fall back, so the host builds on whatever clang the machine ships.
ai_std := $(shell printf 'int main(void){return 0;}' | $(CC) -std=gnu23 -x c -c -o /dev/null - 2>/dev/null && echo gnu23 || echo gnu2x)

ai_cflags = -std=$(ai_std) -g -O2 -pipe $(EXTRA_CFLAGS) \
  -Wall -Wextra -Werror -Wstrict-prototypes -Wno-unused-parameter \
  -Wmissing-field-initializers -Wno-implicit-fallthrough\
  -falign-functions=16 -fomit-frame-pointer -fno-stack-check -fno-stack-protector \
  -fno-exceptions -fno-asynchronous-unwind-tables
# -fcf-protection (Intel CET) is x86-only -- Apple/arm clang rejects it as an
# error. Keep it on every non-Darwin build (Linux x86 + the cross kernels take
# it as before); macOS does without (it has no CET to turn off).
ifneq ($(shell uname -s),Darwin)
ai_cflags += -fcf-protection=none
endif
