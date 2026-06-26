⎕IO←0 ⋄ ⎕PP←17
⎕FIX'file://lib/bench.apl'

⍝ sum of squares of the odd numbers in [0,20000). checksum = 1333333330000.
work←{d←⍳20000 ⋄ +/(d*2)/⍨1=2|d}

_←work bench.Run 'polysum'
