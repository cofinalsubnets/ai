⎕IO←0 ⋄ ⎕PP←17
⎕FIX'file://lib/bench.apl'

⍝ square every element of 0..9999, keep the even squares, sum them.
⍝ checksum = 166616670000.
work←{s←(⍳10000)*2 ⋄ +/s/⍨0=2|s}

_←work bench.Run 'mapfilter'
