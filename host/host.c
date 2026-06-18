// host/ -- per-concern host (POSIX) nif files, auto-globbed into the host build
// and auto-registered. THIS is where app threads add their nifs: aineko -> net.c
// (sockets), bao -> pty.c (ptyrun/reap/kill/winsize). The pattern, top to bottom:
//
//   #include "ai.h"            // the whole nif-writing surface (lvm/Have/Sp/...)
//   static lvm(lvm_foo) { ... return Sp[0] = <result>, Ip++, Continue(); }
//   static union u const nif_foo[] = {{lvm_foo}, {lvm_ret0}};   // 1-arg; curry for more
//   AI_NIF("foo", nif_foo);    // lands in the ai_nifs section, drained at boot
//
// No edit to ai.c / ai.h / main.c -- the Makefile globs host/*.c and main()'s
// boot drains the section. (ai.c/ai.h changes route through the core thread.)
#include "ai.h"
#include <unistd.h>

// (getpid x) -> the running process id as a fixnum (x ignored). The first host
// nif; proves the glob + section registration end to end.
static lvm(lvm_getpid) { return Sp[0] = putcharm(getpid()), Ip++, Continue(); }
static union u const nif_getpid[] = {{lvm_getpid}, {lvm_ret0}};
AI_NIF("getpid", nif_getpid);
