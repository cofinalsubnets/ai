# crew — the kship crew

These are the **agent personality files** for the **kship crew**: the programs that
ride on **kship**, the freestanding ai kernel (a ship in port). Each `.md` is an
*agent brief*: a self-contained doc a dedicated agent
session is pointed at to develop that app — its territory (which files it owns),
its do-not-touch list, the sync rule with the core, its current state, and its
roadmap. One doc per crew member; non-overlapping file territory so the sessions
run in parallel without colliding. (`ai.c`/`ai.h`/`host/main.c` are the only
shared files — core changes route through the core thread, never a crew session.)

The crew is built by [`crew/<member>.md` as personality], coded in `ai`/`host`/`port`,
and (for the runnable ones) installed on `PATH` by `make install`.

## Current crew

| member | what it is | lives in | installed bin |
|---|---|---|---|
| **ai** | the pilot — the mind at the helm, the `decide` step of kship's perceive→decide→act loop (the policy that answers *which way*) | `port/kship/kship.l` (the `policy` seam) | (no bin — the helm itself) |
| **aineko** | a netcat clone (愛猫, "beloved cat") — TCP client/server over the socket nifs | `tools/aineko.l`, `host/net.c` | `aineko` |
| **bao** | the interactive shell / rlwrap-style pty wrapper / debugger (one editor + the condition system) | `ai/bao.l`, `host/pty.c`, `boot/pty.l` | `bao` |
| **cook** | a GNU-make-compatible build tool written in ai (builds the host from scratch) | `cook/cook.l` | `cook` |
| **kship** | the ship itself — the freestanding ai-kernel as a self-driving agent: boots on bare metal, perceives the NIC, runs the language over UDP | `port/kship/` | (boot image: `make kernel KSHIP=1`) |
| **sift** | the garbage collector — tends the two-space copying collector (the litter box): the Cheney loop, the off-pool flip, forwarding, the weak-intern rebuild, the OOM blue floor | the GC cluster in `ai.c` + `ai.h` | (no bin — a core specialist) |
| **siri** | the synthesist — makes the human words match the ai words so everything is green: converges the user-facing namespace, mops compiler internals out of sight | `ai/{ev,prel,egg}.l` + the docs | (no bin — a curator role) |
| **tele** | a PyTorch clone (telescope) — it scopes constellations: tensors + reverse-mode autograd over the galaxy (numeric set), with a small `nn`/`optim` layer; trains a neural net (even on bare metal via kship) | `tele/tele.l` | (library, `-l`'d; demo `tele/xor.l`) |
| **zev** | the parser combinator — a reusable parser-combinator library in ai, lifted and generalized from cook's embedded Makefile importer (one shared `(\ s y n)` vocabulary for the crew) | `parse/zev.l` | (no bin — a library) |

The personality docs are the *source of truth* for each app's design and status;
the code is in the `lives in` column. `make install` puts the runnable ones
(`aineko`, `bao`, `cook`) on `PATH` next to `ai`; kship ships as a bootable kernel
image instead of a bin (`make kernel KSHIP=1` → an ISO you `dd` to a USB stick);
siri and sift are no-bin roles — siri keeps docs and surface in agreement, sift
tends the collector (a core specialist, not a parallel app thread).
