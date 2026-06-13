# jit — the `(call ...)` trampoline

The floor under a love JIT: a nif that jumps into machine code stored in a
`buf` and runs it natively.

```
(call b x)
```

Jump into the bytes of buf `b`, passing `x` as the sole argument and wrapping
the returned machine word as a fixnum. The calling convention is the platform C
ABI — SysV AMD64 puts the argument in `%rdi` and takes the result in `%rax`;
AArch64 uses `x0` for both. The bytes inside `b` are entirely the caller's
responsibility: an ill-formed body is a hard crash, by design. A non-buf
argument runs nothing and returns nothing (`0`) — the only host-safe path.

The nif lives in `love.c` (search `lvm_call`); three lines wire it in — a
forward-decl in the `lvm_t` block, the body next to `lvm_bufnew`, and one entry
in the nif table.

## The finding: the kernel substrate is *just* this trampoline

`jit/probe.l` builds a buf holding six AMD64 bytes —

```
B8 2A 00 00 00   mov eax, 42      ; imm32 little-endian
C3               ret
```

— then `(call b 0)` and prints the result. Run on the **kernel** target under
qemu it returns the immediate exactly (verified at 42 and at 12345). So Limine
maps the HHDM — which backs the kernel heap, hence every `buf` — **without the
NX bit**: kernel data memory is already executable. No page-table work, no
`mprotect`: a love JIT is just love emitting bytes into a `buf` and calling it.

The **host** is the opposite: Linux maps the malloc heap no-execute, so a host
`(call <live buf> ...)` SIGSEGVs on the jump. That is why the corpus test
(`test/jit.l`) exercises only the non-buf guard — executing real bytes is a
kernel-only experiment.

## Reproducing the probe (x86_64 + qemu)

```sh
make host                                  # builds love0 + the bake tools
cp jit/probe.l out/lib/ktests.l            # make the probe the whole K_TEST corpus
out/host/love0 -l love/prelude.l tools/lcatv.l out/lib/ktests.l > out/lib/ktests.h
touch out/lib/ktests.l out/lib/ktests.h
make -s K_TEST=1 out/free/love-x86_64-test.iso
qemu-system-x86_64 -m 256M -M q35 -serial stdio -display none -no-reboot \
  -drive if=pflash,unit=0,format=raw,file=out/dl/edk2-ovmf/ovmf-code-x86_64.fd,readonly=on \
  -cdrom out/free/love-x86_64-test.iso \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04
# expect:  JIT-PROBE-START / JIT-PROBE-RESULT=42 / JIT-PROBE-END
# then restore the real corpus:  make out/lib/ktests.h   (or rm it; the next build re-bakes)
```

`probe.l` ends in `(exit 0)`, which the kernel routes to qemu's isa-debug-exit.

## Caveats / TODO

- **Host-unsafe by nature.** Never `(call ...)` a buf of real code on the host;
  the NX heap faults. The guard for non-bufs is the only path the host gate
  covers.
- **AArch64 cache.** `lvm_call` omits the I-cache flush AArch64 needs after
  writing code (`__builtin___clear_cache(txt(s), txt(s)+len(s))` before the
  jump). Correct on x86_64 only until that is added.
- **No verification.** This is the raw trampoline, nothing more — no semantics,
  no proof. A *verified* JIT is a separate, much larger effort.
