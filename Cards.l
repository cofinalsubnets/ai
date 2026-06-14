; Cards.l -- the project's build, as a cook recipe. make, in love, building love.
;
; run it with the cook.mk front door (`make -f cook.mk test`) or straight:
;     out/host/love -l tools/cook.l Cards.l [ticket]
; the first recipe ('all) is the default ticket.
;
; SCOPE: the cross-cutting verbs + the host build. two rungs are DELEGATED to the
; real Makefile rather than re-expressed here, on purpose:
;   * host -- the C bootstrap (love0 -> reflect data.h -> the love binary) is
;     circular for cook: building love needs love. make owns that rung; this recipe
;     just leans on it (and make no-ops when the binary is already current).
;   * install -- a 50-line install -D file list; make is its source of truth.
; everything else (test, clean, valg, vmret, bench) is the genuine command, ported.
; the kernel/wasm/qemu/repl verbs stay with make (cook's `run` captures stdout and
; waits, so it can't drive qemu, a tty repl, or stream a sub-make) -- cook.mk hands
; those straight through.

; the corpus, in the Makefile's order: the harness first (00-init), the spec
; second (CLAUDE.l), then the rest of test/*.l sorted. built once as a shell word.
(: corpus "test/00-init.l CLAUDE.l $(ls test/*.l | grep -v 00-init)")

; --- the default ticket ----------------------------------------------------------
; all -- the host build. kernel and wasm are make-delegated (see header), so the
; default here is the host binary, exactly as a bare `make` lands on host first.
(recipe 'all '(host) 0)

; --- the host binary (delegated bootstrap) -------------------------------------
(recipe 'host '() '(("make" "host")))

; --- the fast gate -------------------------------------------------------------
; test = the host corpus + the self-hosted love0, each of which MUST print the
; zz-fin "tests pass" summary -- exit 0 alone is a lie (a reader stop drops the
; rest of the stream and still exits 0). love0 prints it TWICE (c0 then ev).
(recipe 'test '(host)
      (L (L "sh" "-c"
            (+ "o=out/host/.test_host; cat " (+ corpus
               " | out/host/love >$o 2>&1; cat $o; grep -q 'tests pass' $o")))
         '("sh" "-c"
            "o=out/host/.test_love0; out/host/love0 </dev/null >$o 2>&1; cat $o; [ $(grep -c 'tests pass' $o) -eq 2 ]")))

; --- the corpus under valgrind -------------------------------------------------
(recipe 'valg '(host)
      (L (L "sh" "-c"
            (+ "cat " (+ corpus
               " | valgrind --error-exitcode=1 --suppressions=tools/valgrind.supp out/host/love")))))

; --- the VM no-return invariant ------------------------------------------------
(recipe 'vmret '(host) '(("out/host/love" "tools/vmret.l" "out/host/love")))

; --- benchmarks ----------------------------------------------------------------
(recipe 'bench '(host) '(("make" "-C" "bench" "bench")))

; --- clean ---------------------------------------------------------------------
(recipe 'clean '() '(("rm" "-rf" "out") ("make" "-C" "wasm" "clean")))

; --- install (delegated) -------------------------------------------------------
(recipe 'install '(host) '(("make" "install")))

(cook (ticket 0))
