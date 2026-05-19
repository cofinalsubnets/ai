(: z (new 0) e (sym 0) m (sym 0)
   (loop x)
     (: cl (edline z " ;; ")
        (? (get 0 'eof z) 0
           (: r (parse cl e m)
              (? (= r m) (loop 0)
                 (= r e) (: _ (edreset z) (loop 0))
                 (: _ (. (ev 'ev r)) _ (putc 10) _ (edreset z) (loop 0))))))
   (loop 0))
