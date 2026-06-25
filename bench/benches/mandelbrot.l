; mandelbrot -- iterate z = z^2 + c over a 128x128 grid of c in [-2,1]x[-1.5,1.5], counting escape
; iterations (|z| > 2) up to 128. checksum = sum of the per-pixel iteration counts (= 424578). ai
; uses the TWIN GEMS (complex scalars ~(re im)) for the z^2+c step -- the one bench exercising the
; complex lane (interpreted; the glaze has no complex lowering). every IEEE-754 language reproduces
; the same escape counts (identical double ops); the ports use a real/imag float pair.
(: maxit 128  W 128  H 128
   (pix cr ci)                                                          ; escape count for the pixel at c = cr+ci*i
    (: (go it z) (? (|| (>= it maxit) (> (+ (* (re z) (re z)) (* (im z) (im z))) 4.0)) it
                    (go (+ it 1) (+ (* z z) ~(cr ci))))                 ; z <- z^2 + c   (twin-gem multiply + add)
       (go 0 ~(0.0 0.0)))
   (mb _)
    (: (rows py acc) (? (>= py H) acc
        (: ci (+ -1.5 (* py (/ 3.0 H)))
           (cols px a) (? (>= px W) a (: cr (+ -2.0 (* px (/ 3.0 W))) (cols (+ px 1) (+ a (pix cr ci)))))
           (rows (+ py 1) (+ acc (cols 0 0)))))
       (rows 0 0))
 (bench "mandelbrot" mb))
