# cook — the make-in-ai build tool

`cook/cook.l` is a GNU-make-compatible build tool written in ai: it reads a
Makefile (or a `Cookfile`), resolves recipes, and runs them — and `cook --emit`
transpiles a Makefile into a flat, fully-resolved `Cookfile`. It already builds the
host from scratch and passes the corpus. The man page is `doc/cook.1`.

## Agent brief — you are the cook thread

You build cook, in parallel with the aineko / bao / kship threads. You have the
**lightest coupling** of the four: cook is pure ai over `ai/cli.l`'s rebound argv,
so it needs **no entry change and no core change** to make progress.

- **Your territory (you own these):** `cook/cook.l`, `cook/cooktest.l`, `cook/`'s
  fixtures, `doc/cook.1`. The cook test is `test_cook` (run by `make -C tools`).
- **Read-only for you:** `ai.h`, this doc, `ai/cli.l` (cook reads the rebound
  `argv` — `cli.l` stops at the first non-flag; cook parses `(cup argv)`).
- **DO NOT EDIT `ai.c` / `ai.h` / `main.c`** or other threads' files
  (`host/*.c`, `tools/aineko.l`, `bao.l`, `kmain.c`). Need a core change? **Ask the
  core thread** (the main session) — but cook almost certainly doesn't need one.
- **First task — the red tests.** `test_cook` is currently **2 pass, 30 FAIL**
  (pre-existing, in the silently-red `test_tools` that `make test` excludes — not a
  regression). Fix them: the failures are cook's make-function handling
  (`dir`/`notdir`/`patsubst`/`filter`/`subst`/…) + the `--emit` round-trip. This is
  a clean, self-contained first task with an exact gate.
- **Then the cook UX** (`cook-build-tool` memory): cook owns its own arg parse over
  the rebound argv — recipes = non-flag args (like `make foo bar`), `-f FILE` for
  the Cookfile, `--emit`, `help`/`version`. No entry change needed today; the fuller
  multi-call decouple (`runtime-personalities-so`) is post-v1.
- **Gate:** `make -C tools` (test_cook) goes green; `make test` stays green (you
  don't touch the corpus or the core).
