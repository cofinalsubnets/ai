; tests for cooperative multitasking: spawn / yield / wait.
; (spawn fn x)  -> pid (positive integer); starts a new task running (fn x).
;                  the main task has reserved pid 0.
; (yield)       -> nil; cooperatively suspends so other ready tasks can run.
; (wait pid)    -> if pid is unknown / non-numeric / refers to the caller, 0.
;                  if the task is dormant (its fn has returned), collect it
;                  from the ring and return its return value.
;                  if the task is still running, yield until it becomes dormant.

(assert
 ; spawn-wait round trip: fn is applied to x; the result flows back through wait.
 (= 42 (: p (spawn (\ x x) 42) (wait p)))
 (= 43 (: p (spawn (\ x (+ x 1)) 42) (wait p)))
 (= 49 (: p (spawn (\ x (* x x)) 7) (wait p)))

 ; spawn returns a positive integer pid (main reserves pid 0).
 (: p (spawn (\ _ 0) 0) _ (wait p) (&& (nump p) (> p 0)))

 ; pids are monotonically increasing within a VM.
 (: a (spawn (\ x x) 0)
    b (spawn (\ x x) 0)
    _ (wait a) _ (wait b)
    (> b a))

 ; wait on an unknown pid returns 0 without blocking.
 (= 0 (wait 99999))
 ; non-numeric pid argument: also 0.
 (= 0 (wait nil))
 ; pid 0 (main) is treated as not-waitable from main itself.
 (= 0 (wait 0))

 ; collecting a dormant task removes it: a second wait on the same pid sees 0.
 (: p (spawn (\ x x) 99)
    (&& (= 99 (wait p)) (= 0 (wait p))))

 ; many tasks can be reaped in any order.
 (: a (spawn (\ x (* x 10)) 3)
    b (spawn (\ x (* x 10)) 4)
    c (spawn (\ x (* x 10)) 5)
    (&& (= 50 (wait c))
        (= 30 (wait a))
        (= 40 (wait b))))

 ; a task may yield mid-execution and still return its value through wait.
 (: p (spawn (\ x (, (yield) (yield) (yield) (+ x 1))) 41)
    (= 42 (wait p)))

 ; nested spawn: a worker can spawn and wait on its own subtask.
 (: p (spawn (\ _ (: q (spawn (\ x (+ x 1)) 10) (wait q))) 0)
    (= 11 (wait p)))

 ; tasks share the heap: a captured table sees writes from the worker.
 (: t (new 0)
    p (spawn (\ k (put k 'done t)) 'key)
    _ (wait p)
    (= 'done (get 0 'key t)))

 ; waiting on a still-running task blocks until it finishes.
 ; here the worker only completes after several yields; main's wait yields
 ; alongside it and eventually returns the result.
 (: t (new 0)
    _ (put 'n 0 t)
    p (spawn (\ _ (: (loop) (? (< (get 0 'n t) 3)
                                (, (put 'n (+ 1 (get 0 'n t)) t)
                                   (yield)
                                   (loop))
                                'done)
                    (loop))) 0)
    r (wait p)
    (&& (= 'done r) (= 3 (get 0 'n t))))
)
