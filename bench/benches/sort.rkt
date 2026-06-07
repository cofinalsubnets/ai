#lang racket/base
;; sort N pseudo-random ints (MINSTD LCG), order-dependent rolling-hash checksum.
(require "../lib/bench.rkt")
(define N 5000)
(define (gen n)
  (let loop ([i 0] [x 1] [acc '()])
    (if (< i n)
        (let ([nx (modulo (* 16807 x) 2147483647)]) (loop (+ i 1) nx (cons nx acc)))
        acc)))
(define (hsh l)
  (let loop ([l l] [h 0])
    (if (pair? l) (loop (cdr l) (modulo (+ (* h 31) (car l)) 1000000007)) h)))
(bench "sort" (lambda () (hsh (sort (gen N) <))))
