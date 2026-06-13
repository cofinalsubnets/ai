; jit -- the (call buf x) trampoline jumps into the machine code in a buf and
; runs it natively (SysV/AArch64 ABI: the arg in the first register, the result
; in the return register, wrapped as a fixnum). Executing real bytes is
; KERNEL-ONLY: the host maps its heap no-execute, so a host (call <live buf> ..)
; SIGSEGVs by design, while the freestanding kernel's HHDM is executable and
; (call ..) is the JIT floor (see jit/README.md + jit/probe.l, verified under
; qemu returning 42 and 12345). These asserts cover ONLY the host-safe guard:
; a non-buf argument jumps nowhere -- it nets nothing.
(assert
 (lamp call)                  ; the nif is present and applicable
 !(call 5 0)                  ; not a buf -> nothing (no jump)
 (0 = (call 'sym 0))          ; a symbol is not a buf
 !(call "text" 0)             ; a string is not a buf (bufp is false for strp)
 !(call () 0))                ; nothing in -> nothing out
