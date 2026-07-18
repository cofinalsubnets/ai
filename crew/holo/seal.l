; crew/holo/seal.l -- the assembler's MODULE BOUNDARY. crew/holo/holo.l opened a named scope
; ((enter 'holo)); the core and every backend loaded into it, so the layer IS the module:
; closing it here unwinds the chain and REGISTERS the built book as `holo` in the module
; registry. a consumer either splices it -- (use 'holo), bare names resolve, cleared by a
; bare (leave ()) -- or reaches one member through the opaque accessor: (from 'holo 'assemble);
; (from 'holo 'keys) lists the internals, every one a probe away. loads after the last
; backend -- host boot and the mooncc cat seal; a dev/test cat-stream (test_holo, the enc
; oracles) leaves the layer open and reads bare. a later backend joins a SEALED holo the
; runtime way: (enter ()) (use 'holo) <backend.l> (leave ()) -- defbackend pins through the
; chain into this book's live `backends` tablet.
(leave ())
