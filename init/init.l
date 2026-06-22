; --- init: a service supervisor modeled in ai (a runnable sketch) ---
; the EXECUTABLE companion to the "ai as pid 1" idea -- the Tier-1 init (runit/s6/
; dinit class: own unit format, no D-Bus), the Linux-altitude sibling of kship
; (port/kship/kship.l, the freestanding-kernel altitude). SAME program, same shape:
; a perceive->decide->act supervisor with a watchdog over checkpointable state. kship
; drives green tasks + a NIC; init drives PROCESSES + signals over the host kernel's
; stack. the supervisor IS kship's watchdog (supervise/mission) generalized to N units.
;
; like kship.l and boot/tag.l this is a SKETCH -- it models the parts that STAY ai so
; the shape runs and is probed on the host before the C is written. the ONLY genuinely
; real part today is the ONESHOT lane: it forks/execs/waits a real child via the `run`
; nif (host/main.c). long-running SERVICES are modeled as green tasks (spin/catch); a
; crash is a `scare` the watchdog `help` welps to () -- the SAME shape recovery kship
; uses, so the restart loop is real even though the "process" is a thunk. run it:
;   out/host/ai -l init/init.l -e "(demos 0)"
; (the file only DEFINES -- a plain load prints nothing; -l preloads it into the shared
; global scope so the -e call finds `demos`.)
;
; the new C an ACTUAL pid1 needs is small and core-clean (host/init.c via the AI_NIF
; glob, no ai.c/ai.h edit -- the same discipline as ain/bao): fork/execve, a NON-blocking
; waitpid loop (reap arbitrary reparented orphans), signalfd (SIGCHLD/SIGTERM become
; perceive events, merged with timers by ai_wait_fds exactly like {nic, clock}), mount
; (early /proc, /sys, devtmpfs), and the cgroup-v2 writes. everything BELOW that is this
; file -- the dependency graph, the restart policy, the checkpoint -- already ai.

(: (note s) (: _ (puts s) (puts "\n"))               ; the narrator: a line to the console

   ; --- a unit is an IMMUTABLE list (name kind cmd restart deps) --- show/read
   ; checkpoints it for free (the kship.md rule: state is an ai value, persistence is
   ; show/read). `kind` is 'oneshot (a real argv for `run`) or 'service (a thunk modeling
   ; the long-running process). `restart` is 'no | 'on-fail | 'always (systemd's Restart=).
   ; `deps` is the After= list -- names that must be up before this one starts.
   (nth l i) (? (= i 0) (cap l) (nth (cup l) (- i 1)))
   (unit name kind cmd restart deps) (L name kind cmd restart deps)
   (u-name u) (nth u 0)   (u-kind u) (nth u 1)   (u-cmd u) (nth u 2)
   (u-restart u) (nth u 3) (u-deps u) (nth u 4)
   (find units name) (? !units ()                    ; the unit with this name, or ()
                        (? (id? (u-name (cap units)) name) (cap units)
                           (find (cup units) name)))
   (rev l) (foldl (\ a x (link x a)) () l)            ; prepend-fold = reverse

   ; --- the registry --- a live book name->status ('up | 'done | 'failed; absent =
   ; 'down). MUTABLE (a book), the one place state is shared while units come and go;
   ; `snap` reads it back to the honest list for the checkpoint. a unit is "started"
   ; once it is up (a service running) or done (a oneshot that completed).
   (up? reg name) (: s (peep reg name 'down) (? (id? s 'up) 1 (id? s 'done)))

   ; --- the watchdog: supervise one SERVICE (Restart=) --- spin the thunk (the modeled
   ; process); if it faults, the `help` below welps the task to (), so `catch` comes back
   ; falsey and we RESTART per policy, counting attempts in `cnt`. clean exit (a truthy
   ; return) -> up. give up after `tries-cap`. on metal: fork+exec, and THIS loop is the
   ; SIGCHLD handler re-spawning the pid per its Restart= -- identical control flow.
   tries-cap 3
   (supervise name thunk policy cnt)
     (: p (spin thunk 0)
        r (catch p)
        (? r 1                                        ; clean -> running
           (: n (+ 1 (peep cnt name 0)) _ (pin cnt name n)
              (? (? (id? policy 'no) 0 (< n tries-cap))
                 (: _ (note (+ "    " (+ (show name) (+ " crashed -> restart #" (show n)))))
                    (supervise name thunk policy cnt))
                 (: _ (note (+ "    " (+ (show name) " gave up"))) ())))))

   ; --- act: bring ONE unit up --- a oneshot really forks/execs/waits a child (the wire
   ; out to a real process: `run` returns (exit-code . captured-stdout), so the REAL exit
   ; status drives done/failed). a service is supervised. returns the registry with this
   ; unit's status pinned.
   (start1 reg cnt u)
     (: name (u-name u)
        (? (id? (u-kind u) 'oneshot)
             (: res  (run (u-cmd u))                  ; REAL child (host/main.c fork+exec+wait)
                code (cap res)  text (cup res)         ; (exit . stdout)
                _    (note (+ "  [oneshot] " (+ (show name) (+ " -> \"" (+ text (+ "\" (exit " (+ (show code) ")")))))))
                (pin reg name (? (= code 0) 'done 'failed)))
           (: ok (supervise name (u-cmd u) (u-restart u) cnt)
              _ (note (+ "  [service] " (+ (show name) (? ok " up" " FAILED"))))
              (pin reg name (? ok 'up 'failed)))))

   ; --- decide+act: dependency-ordered boot --- bring `name` up, but its After= deps
   ; FIRST (a DFS over the graph; up? dedups so a shared dep starts once). `boot` folds
   ; the whole unit list through it. this is the topological start systemd orders by
   ; Requires=/After=; a real init would also detect cycles (no progress -> raise).
   (ensure reg cnt units name)
     (? (up? reg name) reg
        (: u    (find units name)
           reg' (foldl (\ r d (ensure r cnt units d)) reg (u-deps u))  ; deps first (fresh
           (start1 reg' cnt u)))                                       ; name: a self-rebind reads missing)
   (boot units) (: cnt (tablet 0)
                   (foldl (\ reg u (ensure reg cnt units (u-name u))) (tablet 0) units))

   ; --- shutdown --- stop in REVERSE start order (dependents before their deps), the
   ; mirror of boot. modeled as a status flip; on metal: SIGTERM, wait, SIGKILL on a
   ; timeout, each in its cgroup.
   (stop1 reg name) (: _ (note (+ "  stop " (show name))) (pin reg name 'down))
   (shutdown reg names) (foldl stop1 reg names)

   ; --- checkpoint --- the live book -> an immutable (name status) list, show/read-able
   ; (a book does not round-trip; the list does). persistence is show/read, end to end.
   (snap reg names) (map (\ n (L n (peep reg n 'down))) names))

; --- install the watchdog as the global help (the floor that turns a service's fault
; into () so the supervisor sees a falsey `catch`) --- read control keeps the protocol;
; a real scare just welps (the supervisor narrates restarts itself; a true init would
; log the fault to the journal here). mirrors kship.l / repl.l's shell-help, quieter.
(: help (\ s a b (? (more? s) (welp s a b) (welp s a b))))

; --- the demos, as a CALLABLE function (not auto-run) ---
(: (demos _)
   (: cr (tablet 0)                                  ; per-name attempt counter for the flaky service
      ; a flaky service: crashes until its k-th start, then runs clean ('ok) -- models a
      ; process that exits nonzero until some dependency/race settles.
      svc    (\ name k (\ _ (: n (+ 1 (peep cr name 0)) _ (pin cr name n)
                               (? (< n k) (scare 'crash name) 'ok))))
      ok-svc (\ _ 'ok)                                ; a clean service: up on the first try
      units (L
        (unit 'netd    'service ok-svc            'on-fail ())
        (unit 'logd    'service ok-svc            'on-fail ())
        (unit 'dbusd   'service ok-svc            'on-fail (L 'logd))           ; after logd
        (unit 'app     'service (svc 'app 3)      'on-fail (L 'netd 'dbusd))    ; crashes twice, then up
        (unit 'brittle 'service (svc 'brittle 9)  'no      ())                  ; crashes, Restart=no -> failed
        (unit 'hello   'oneshot (L "echo" "-n" "init: a real child says hi")
                                                  'no      (L 'app)))           ; a REAL forked child, after app
      _   (note "-- ai-init: bring up the unit graph (deps first; services modeled, oneshot real) --")
      reg (boot units)
      _   (note "-- final state (the checkpoint -- a show/read-able value) --")
      _   (each (snap reg (map u-name units))
                (\ pr (note (+ "  " (+ (show (cap pr)) (+ " = " (show (caup pr))))))))
      _   (note "-- graceful shutdown (reverse start order) --")
      _   (shutdown reg (rev (map u-name units)))
      0))
