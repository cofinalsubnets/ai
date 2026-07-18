; crew/kore/asbook.l -- splice the assembler module for the rest of the cat. elf.l /
; obj.l / link.l / gen.l read holo names BARE (catall, le*, lay, laylax, patch-with,
; holo-bytes ..); this one form resolves them: the registered `holo` module splices
; just below the cat's top layer, so those reads fold at each file's own compile while
; the cat's own defglobs stay on top, shadow-proof. kore's cat order: .. asbook.l,
; crew/holo/elf.l, crew/kore/kore.l; mooncc's: a FRESH holo build + seal, then this.
(use 'holo)
