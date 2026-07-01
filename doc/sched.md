# A park-based task scheduler

Turn the core's **poll-based** waits into **parks**, so `lvm_yield_sw` can reach a real
*quiescent* point — every live task waiting on a genuine event. That one change is what
lets a native host **block** efficiently *and* lets the wasm host **unwind out of `ai_eval`
and resume on an event** — no Asyncify, no busy-spin, and bao's `do_eval` loses its poll loop.

**Design study — not yet built.** A runnable model lives in
[`doc/proto/sched.l`](proto/sched.l) — a task is `(pid kind arg)`, a world is `(tasks clock fds)`,
and its 11 checks pin the invariants (most pointedly **(4)**: a mutual join is *detected* as
deadlock where today's poll-catch spins forever). `make test`-green via the strict gate
(`cat test/00-init.l doc/proto/sched.l | out/host/ai`).

This is a **core** change (ai.c/ai.h task primitives + the host `ai_wait_fds` boundary, which
also touches `host/init.c:110` and the kernel wait). It is bigger than bao; it is the lever bao
and the [browser terminal](webterm.md) both turn out to need.

## Why

ai already has a cooperative scheduler with fd-parking and timers — but only *two* of its waits
are real event-parks:

- `get`/`lvm_fgetc` (ai.c:3710-3712): not ready → set `next_wait_fd`, `Ap(lvm_yield_sw)`. A genuine **fd-park**.
- `rest`/`lvm_sleep` (ai.c:2766): set `next_wake_at`, yield. A **timer-park**.

The task waits are **polls**:

- `catch`/`lvm_wait` (ai.c:2717): if the target is still running it yields *without advancing `Ip`*
  and **clears `next_wait_fd`/`next_wake_at`** (ai.c:2737-2738). So a `catch`ing task parks on
  *nothing* — `find_runnable` sees `wait_fd < 0` and reschedules it every pass. A busy spinner.
- `back?`/`lvm_donep` (ai.c:2742) and `cue?`/`lvm_key` (ai.c:4247) are polls too (`cue?` is even
  hardcoded to `ai_stdin`, ai.c:4248).

So `lvm_yield_sw` can **never** observe "everyone is parked on a real event" while any task is
poll-waiting: something is always runnable, so it can neither sleep nor unwind. That is the root of
two symptoms — bao's `do_eval` *must* busy-poll (`cue?`/`rest`, bao.l:345-353) to stay responsive,
and **bao can't run on wasm at all** (the no-op `ai_wait_fds` makes the mono wait loop at
ai.c:2609 spin forever, never returning to the browser).

## What the scheduler is today

Three functions, over a singly-linked ring of task nodes (`g->tasks`, threaded by `->m`):

- **`find_runnable`** (ai.c:2616-2621): first non-dormant peer whose `wake_at <= now` **and**
  `wait_fd < 0 || ai_ready(wait_fd)`.
- **`lvm_yield_sw_mono`** (ai.c:2601): one task — block in place (`while (!ai_ready) ai_wait_fd`, or
  spin-sleep a timer).
- **`yield_sw_wait`** (ai.c:2623): collect every parked task's `{fd, wake_at}`, one blocking
  `ai_wait_fds(fds, nfds, timeout)`, re-find.

The task node (ai.c:2699): `[next, ip, pid, wake_at, wait_fd, stack…]`. `wake_at` and `wait_fd`
are the two park fields `find_runnable` reads.

## The one insight: a join is a runnability predicate

`find_runnable` already ANDs two predicates: `wake_at <= now` and `wait_fd < 0 || ai_ready(wait_fd)`.
A join is just a **third**, perfectly symmetric to the fd one:

```
wait_pid < 0  ||  dormant(wait_pid)
```

So you **do not wake joiners**. `lvm_task_exit` (ai.c:2695) does *nothing* special — the next
scheduler pass *computes* a joiner's runnability from its target's dormancy, exactly as it computes
fd-readiness from `ai_ready`. **No backlink walk, no joiner list, no new GC links.** `dormant(pid)`
is an O(ring) scan, but the ring is tiny and the scan runs only at a yield — the same shape as the
existing `ai_ready` check.

The model encodes this directly (`runnable?` in `doc/proto/sched.l`): `'fd → (amem? n ready)`,
`'timer → (<= wake clock)`, `'join → (dormant? target)`. Assert **(1)** shows a joiner parks while
its target is live and is runnable the instant it is dormant — the joiner never mutated, the target
never "waking" anyone.

## Joins never reach the host

A join is **internal** — it never enters the host wait-set:

- If the target is **alive**, the target (or its chain) is itself runnable, so `find_runnable`
  returns *it* — the scheduler makes progress without any wait (model assert **(2)**, first half).
- Once the target is **dormant**, the joiner is runnable on the next pass (assert **(2)**, second half).

So `find_runnable` returns NULL — the true quiescent point — **only** when every live task is parked
on an fd or a timer. Those, and only those, form the host wait-set. A purely-join cycle with no
external wait is therefore not a wait at all: it is a **deadlock**, and the model detects it as one
(assert **(4a)**) — exactly the world today's poll-catch spins on forever (assert **(4b)**, the
load-bearing pathology). The lone-task scare (ai.c:1804) generalizes to "no runnable task and an
empty external wait-set."

## The suspendable boundary: the host gets to decline

Collapse `lvm_yield_sw_mono` + `yield_sw_wait` into one step: compute the external wait-set
(fds ∪ min-timer); if it is empty and nothing is runnable → deadlock; otherwise hand it to the host
— **and let the host decline to block**:

- **native** (`host/main.c:44` `poll`, `port/inle/kmain.c:241` halt): block as today, return when
  something fires. Zero behavioural change — native never unwinds.
- **wasm**: it *can't* block. So instead of spinning the no-op `ai_wait_fds`, the scheduler returns
  the **yield status** up the trampoline. This rides an **existing** path: `_lvm_yieldk`
  (ai.c:1742-1745) already ends an eval with `Pack(g); encode(g, ai_status_yield)`, and under the
  non-tco build `ai_status_yield == ai_status_eof` (ai.c:103-105), which the trampoline driver
  exits on and unwraps:

  ```c
  #else                                   // ai_tco == 0 -- the wasm build
   while (ai_ok(g)) g = g->ip->ap(g);     // each op RETURNS the next g; loop exits on non-ok
   if (ai_code_of(g) == ai_status_eof) g = ai_core_of(g);
   return g;
  #endif                                  // ai.c:1823-1827
  ```

  `ai_eval` returns to JS; a new `ai_resume(g)` re-enters the same loop on the same `g` when the page
  sees the awaited fd/timer fire. `g` is the whole VM and tasks are heap continuations, so resume is
  "run the driver again." The fault barrier (ai.c:1777-1819) is tco+hosted only, so the wasm
  trampoline unwinds cleanly with nothing to tear down.

New host surface, total: a way for the wait to **decline** (e.g. `ai_wait_fds` returns "I didn't
wait", or an `ai_can_block()` predicate), accessors for the pending wait-set (fd + wake), and
`ai_resume`. Native frontends implement decline = false and are untouched.

## The task node: one new field

A join needs a `wait_pid` beside `wait_fd` in the node (ai.c:2699): the header grows 5 → 6 words,
shifting the stack to `N[6]`. The mechanical blast radius — every `+ 5` that means "skip the header
to the stack": spawn's `N[5]=x, N[6]=fn` (ai.c:2709-2710), the yield snapshot's `next + 5` /
`memcpy(N+5, …)` (ai.c:2662, 2671, 2683, 2690), the fault-recovery `next + 5` (ai.c:1811), and the
`ttag` thread-length tags. All mechanical, all under the GC write-barrier the ring already maintains
(`gen_wb` at the relink sites, ai.c:2686/2713).

## The cascade

Once waits are parks, three things downstream simplify — and one of them is the whole reason this
came up:

- **bao's `do_eval`** (bao.l:345-353) drops its `cue?`/`rest` poll: spawn the worker, the foreground
  `catch`es it (now a real park), a tiny watcher parks on stdin for `^C`. The scheduler blocks on
  `{stdin, worker-exit}`. Model assert **(6)** is this exact shape — the worker runs while the
  foreground is parked on it (no spin), and the foreground wakes with the answer when it exits.
- **`cue?`** demotes from load-bearing to a convenience (and its `ai_stdin` hardcoding, ai.c:4248,
  becomes a candidate for removal): you *park* on input now, you don't poll readiness.
- **the [browser terminal](webterm.md)** needs no Asyncify — its Stage 2 becomes "run `(shell 0)`;
  on a park-return, wait on the surfaced fd/timer via the event loop; `ai_resume`." See `webterm.md`.

## Staging into C (each stage keeps `make test` green)

1. **The join predicate.** Add `wait_pid` to the node; `find_runnable` ANDs `dormant(wait_pid)`;
   `catch`/`back?` park on the pid instead of clearing-and-respinning. Native behaviour is
   *identical* (joins resolve in-VM, the host wait is unchanged), so host + ai0 + kernel stay green —
   this stage is pure internal cleanup with no observable change.
2. **The declinable host boundary + `ai_resume`.** `ai_wait_fds` may decline; the scheduler returns
   the yield status when it does; expose the wait-set; add `ai_resume`. Only the wasm host declines;
   native and kernel are untouched.
3. **bao's `do_eval`.** Rewrite to spawn + `catch` + a stdin `^C` watcher; demote/retire `cue?`.
4. **Wire the browser terminal** to the resume loop (this is `webterm.md` Stage 2, now Asyncify-free).

## Verification

The model's 11 checks (`doc/proto/sched.l`) are the spec the C must meet: the join pull-predicate
**(1)**, joins-never-hit-the-host **(2)**, quiescence-parks-not-spins **(3)**, the load-bearing
deadlock-vs-spin pair **(4)**, fairness **(5)**, and the reborn `do_eval` shape **(6)**. The
existing task/GC stress tests are the runtime oracle for the node-layout change. A `rocq/` proof
that the C scheduler refines the model — "no live task is starved while a wake condition it is
parked on is satisfiable" — is the same larger effort `gc.v` represents for the collector.

## Not yet / open

- **Dormant-task reaping still walks.** The *wake* is now walk-free (a pull predicate), but when a
  joiner finally reads the retval, `lvm_wait` still unlinks the dormant node by finding its
  predecessor (the O(ring) walk at ai.c:2725-2727). Making *that* O(1) wants a doubly-linked ring (a
  word per node + barrier upkeep) — deferred; the walk is once-per-join and bounded.
- **Multiple joiners on one pid.** With the pull predicate all joiners become runnable at once; the
  first to run `lvm_wait` reaps the node and gets the retval, the rest find the pid gone and read
  `nil` (today's single-reap semantics, ai.c:2740). Decide whether the retval should persist for all
  joiners (keep the dormant node until the last joiner) or stay first-wins.
- **`cue?`/`lvm_key`** — keep as a convenience or retire once nothing needs it.
- **Wake fairness** across many tasks ready at once (round-robin vs ring order) — today's ring order
  is fine; revisit only if a workload starves.
