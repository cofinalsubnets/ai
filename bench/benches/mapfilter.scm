; list pipeline: square every element, keep the even results, sum them.
(load "../lib/bench.scm")
(define data (let loop ((i 9999) (a '())) (if (< i 0) a (loop (- i 1) (cons i a)))))
(define (sq x) (* x x))
(bench "mapfilter" (lambda () (sum-list (filter even? (map sq data)))))
