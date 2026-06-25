; layer-2 spike: the TASK SCHEDULER decision, modelled in ai -- a runnable, value-level model of
; what `lvm_yield_sw` (ai.c:2641) decides each time a task yields: run a peer, PARK on an external
; event (hand the wait-set to the host), or declare DEADLOCK. it is the design-by-prototype step for
; the scheduler redesign (doc/sched.md): turn the core's POLL-based waits into PARKS, so the scheduler
; can reach a real quiescent point -- which is what lets a native host block efficiently AND lets the
; wasm host unwind out of ai_eval and resume on an event (no Asyncify).
;
; THE PROBLEM THIS MODELS. today only `get`/lvm_fgetc (fd-park, ai.c:3710) and `rest`/lvm_sleep
; (timer) are real event-parks; `catch`/lvm_wait (ai.c:2732) re-scans the ring and CLEARS its fd/wake
; (2737), so a waiter is perpetually runnable -- a busy spinner. `back?`/`cue?` poll likewise. So
; lvm_yield_sw can never see "everyone parked on a real event": there is always something runnable, so
; it can neither sleep nor unwind. that is why bao's do_eval must busy-poll, and why bao can't run on
; wasm (the no-op ai_wait_fds spins).
;
; THE INSIGHT (the one that makes it small). a JOIN is a fourth RUNNABILITY PREDICATE, symmetric to
; the fd one: find_runnable already gates on `wait_fd < 0 || ai_ready(wait_fd)` (ai.c:2620); add
; `wait_pid < 0 || dormant(wait_pid)`. so you DON'T wake joiners -- lvm_task_exit does nothing -- the
; next scheduler pass COMPUTES a joiner's runnability from its target's dormancy. no backlink walk, no
; joiner list, no new GC links. and a JOIN NEVER REACHES THE HOST: a live target is itself runnable
; (the scheduler runs IT), and a dormant target wakes the joiner in-VM; only fd/timer waits -- genuine
; external events -- ever hit the host wait-set. quiescence then = all live tasks parked on fd/timer.
;
; THE CORRESPONDENCE TO REAL ai:
;   task state    <->  the task node [next, ip, pid, wake_at, wait_fd, ...] (ai.c:2699) + a NEW
;                      wait_pid header word; here a task is (pid kind arg), kind in run/fd/timer/join/done.
;   runnable?     <->  find_runnable's per-task test (ai.c:2616) -- 'poll models TODAY's busy catch.
;   step          <->  lvm_yield_sw's decision: a runnable peer (2643), else yield_sw_wait's host wait
;                      (2623), else the lone-task scare (2646/1804). 'park = block-or-unwind at the host.
;
; run:    out/host/ai doc/proto/sched.l
; strict: cat test/00-init.l doc/proto/sched.l | out/host/ai          (00-init makes `assert` enforce)
;
; the load-bearing pair is (4): mutual join is DETECTED as deadlock, where TODAY's poll-catch (4b)
; spins forever (busy-runnable, the host never sleeps) -- the model reproduces the exact pathology the
; redesign removes, so the park model earns its keep by construction.

(:
 ; --- list/set helpers (addrs and pids are charms, compared by =) ---
 (nth l i)    (? (= i 0) (cap l) (nth (cup l) (- i 1)))
 (amem? x l)  (? (atom? l) 0 (= x (cap l)) 1 (amem? x (cup l)))   ; spine test, never (! l): ! reads the NET

 ; --- a task is (pid kind arg): kind one of run/fd/timer/join/done; arg the fd / wake / target / retval ---
 (t-run p)     (L p 'run 0)
 (t-fd p n)    (L p 'fd n)        ; parked on fd n     (runnable iff n is ready)
 (t-timer p k) (L p 'timer k)     ; parked until clock k
 (t-join p q)  (L p 'join q)      ; parked on pid q    (runnable iff q is dormant)  -- the NEW park
 (t-done p v)  (L p 'done v)      ; dormant, retval v
 (t-poll p q)  (L p 'poll q)      ; the OLD catch: re-scans the ring, so ALWAYS runnable (busy)
 (t-pid t)  (nth t 0)  (t-kind t) (nth t 1)  (t-arg t) (nth t 2)
 (live? t)  (! (= 'done (t-kind t)))

 ; --- a world is (tasks clock fds): the ring, the clock, and the set of fds the host says are ready ---
 (w ts clk fds) (L ts clk fds)
 (w-tasks w) (nth w 0)  (w-clock w) (nth w 1)  (w-fds w) (nth w 2)
 (by-pid p ts)  (? (atom? ts) () (= p (t-pid (cap ts))) (cap ts) (by-pid p (cup ts)))
 (dormant? p ts) (: t (by-pid p ts) (&& (two? t) (= 'done (t-kind t))))

 ; --- THE RUNNABILITY PREDICATE: the four parks read as one test (find_runnable, ai.c:2616-2620) ---
 (runnable? t w)
   (: k (t-kind t)
      (? (= k 'run)   1
         (= k 'fd)    (amem? (t-arg t) (w-fds w))           ; <-> ai_ready(wait_fd)
         (= k 'timer) (<= (t-arg t) (w-clock w))            ; <-> wake_at <= now
         (= k 'join)  (dormant? (t-arg t) (w-tasks w))      ; <-> the NEW wait_pid: dormant(target)?
         (= k 'poll)  1                                     ; <-> TODAY's busy catch: always runnable
         0))                                                ; 'done -> never runnable

 (runnables w) (filter (\ t (runnable? t w)) (w-tasks w))
 (find-run w)  (: rs (runnables w) (? (two? rs) (t-pid (cap rs)) ()))   ; first runnable pid, or ()
 ; the external wait-set: LIVE tasks parked on a genuine external event (fd/timer). joins are NOT here.
 (ext-waiters w) (filter (\ t (|| (= 'fd (t-kind t)) (= 'timer (t-kind t)))) (w-tasks w))
 (wait-fds w)    (map t-arg (filter (\ t (= 'fd (t-kind t))) (w-tasks w)))

 ; --- THE DECISION (lvm_yield_sw): run a peer, else PARK on the external set, else DEADLOCK/idle. ---
 (step w)
   (: r (find-run w)
      (? r                          (L 'run r)            ; a runnable task -> switch to it
         (two? (ext-waiters w))     (L 'park (wait-fds w)) ; nothing runnable, real external waits -> host waits
         (two? (filter live? (w-tasks w))) (L 'deadlock)  ; live tasks, none runnable, no external event -> deadlock
         (L 'idle)))                                       ; no live tasks at all
 (d-tag d) (cap d)  (d-val d) (cap (cup d))

 ; ================================ self-checks ================================

 ; (1) a JOIN is a PULL predicate: parked while the target runs, runnable once it is dormant -- and the
 ;     joiner is NEVER mutated and the target NEVER "wakes" anyone (lvm_task_exit is a no-op).
 _ (assert "(1) join parks while its target is live, wakes when it is dormant -- pull, no wake-call"
     (: A (t-join 1 2) B (t-run 2)  (! (runnable? A (w (L A B) 0 ()))))      ; B alive  -> A parked
     (: A (t-join 1 2) B (t-done 2 'v) (runnable? A (w (L A B) 0 ()))))      ; B dormant-> A runnable

 ; (2) the scheduler runs the LIVE target, not the host wait -- a join resolves IN-VM, never reaching
 ;     the host. so the host wait-set is fd/timer only.
 _ (assert "(2) a live join target runs first; once dormant the joiner runs -- joins never hit the host"
     (: A (t-join 1 2) B (t-run 2)
        d (step (w (L A B) 0 ()))     (&& (= 'run (d-tag d)) (= 2 (d-val d))))   ; B runs (not park)
     (: A (t-join 1 2) B (t-done 2 'v)
        d (step (w (L A B) 0 ()))     (&& (= 'run (d-tag d)) (= 1 (d-val d)))))  ; then A runs

 ; (3) QUIESCENCE: all live tasks parked on fd/timer -> the scheduler PARKS (hands the wait-set up),
 ;     it does NOT spin; a ready fd then makes its task run.
 _ (assert "(3) all live tasks parked on external events -> PARK (block native / unwind wasm), not spin"
     (: A (t-fd 1 3) B (t-timer 2 100)
        d (step (w (L A B) 0 ()))     (= 'park (d-tag d)))                       ; fd 3 unready, clock 0 < 100
     (: A (t-fd 1 3) B (t-timer 2 100)
        d (step (w (L A B) 0 (L 3)))  (&& (= 'run (d-tag d)) (= 1 (d-val d)))))  ; fd 3 ready -> A runs

 ; (4) THE LOAD-BEARING PAIR. mutual join is DETECTED as deadlock under the new park model; the SAME
 ;     world under today's poll-catch SPINS forever (busy-runnable -> 'run, the host never sleeps) --
 ;     the precise pathology the redesign removes.
 _ (assert "(4a) mutual join is detected as DEADLOCK (no runnable, no external wait, live tasks remain)"
     (: A (t-join 1 2) B (t-join 2 1)
        d (step (w (L A B) 0 ()))     (= 'deadlock (d-tag d))))
 _ (assert "(4b) the OLD poll-catch SPINS on that same world -- always runnable, so no deadlock, no park"
     (: A (t-poll 1 2) B (t-poll 2 1)
        d (step (w (L A B) 0 ()))     (= 'run (d-tag d))))

 ; (5) FAIRNESS: a runnable task with a far-future sleeping peer runs NOW (not throttled to the peer's
 ;     wake) -- the case ai.c:2647-2654 guards by hand.
 _ (assert "(5) a runnable task with a far-future sleeping peer runs now (no throttle to the peer)"
     (: A (t-run 1) B (t-timer 2 9999)
        d (step (w (L A B) 0 ()))     (&& (= 'run (d-tag d)) (= 1 (d-val d)))))

 ; (6) bao's do_eval, reborn: a worker task; a foreground that JOINS it (parks, never polls); a stdin
 ;     watcher parked on fd 0 for ^C. while the worker runs it is scheduled (no spin); when it is done
 ;     the foreground wakes with the answer. the host only ever waits on fd 0 -- after real work is done.
 _ (assert "(6) do_eval rewritten: worker runs while foreground joins it; foreground wakes when it exits"
     (: W (t-run 3) F (t-join 9 3) V (t-fd 8 0)
        d (step (w (L F V W) 0 ()))   (&& (= 'run (d-tag d)) (= 3 (d-val d))))   ; worker runs; F & V parked
     (: W (t-done 3 'ans) F (t-join 9 3) V (t-fd 8 0)
        d (step (w (L F V W) 0 ()))   (&& (= 'run (d-tag d)) (= 9 (d-val d)))))  ; worker done -> F wakes

 _ (. ";; doc/proto/sched.l: scheduler-decision model self-checks pass --\n")
 _ (. ";; join is a 4th runnability predicate (pull, no wake); joins resolve in-VM and never reach the\n")
 _ (. ";; host; quiescence = all live tasks parked on fd/timer -> PARK; mutual join is DEADLOCK (4a)\n")
 (. ";; where today's poll-catch spins forever (4b) -- the pathology the park model removes.\n"))
