; crew/utils/core.l -- the line tools, the coreutils batch of aiutils: cat, echo, head,
; tail, wc, sort, uniq, tee, seq, yes, true, false, basename, dirname. every tool is a
; <name>-main (the args after its name -> conversation on the ports -> nap, the exit
; door), dispatched by the multi-call `au` (crew/utils/au.l holds the registry). this
; file is a TOOLBOX, not a tool: no seat of its own, au is its door. it rides text.l's
; lines/unlines and loads right after text.l in the cat, so the capture law folds the
; real bridge here before cook.l's later `lines` leak can shadow it. a body-less
; top-level `:` -- the u-floor (shared helpers, the unified layer's prefix) and the
; mains leak; everything else stays local to its define. the GNU faces we keep exact
; (the smokes in `make test_utils` hold them to the byte): wc pads every field to the
; digit width of the byte TOTAL, uniq -c wears width 7, head/tail banner many files
; with ==> name <== and a blank line between.
(:
   ; -- the u-floor --
   ; decimal text -> a charm (a leading - reads negative)
   (uatoi s)
    (: n (tally s)
       (go i acc) (? (< i n) (go (+ i 1) (+ (* 10 acc) (- (s i) 48))) acc)
       (? (&& (< 0 n) (= (s 0) 45)) (- 0 (go 1 0)) (go 0 0)))
   ; a path -> (1 text) when it opens, () when it does not (au.l's read-text shape)
   (uread p) (: q (open p "r") (? q (: t (slurp q) _ (close q) (L 1 t)) ()))
   ; complain on err and leave through the exit door with code c
   (udie c m) (: _ (say err m) _ (put err 10) (nap c))
   ; left-pad with spaces to width w (a wider count never shrinks)
   (upad w s) (? (< (tally s) w) (upad w (+ " " s)) s)
   ; join texts with single spaces
   (ujoin a) (? (! (two? a)) ""
                (! (two? (cup a))) (cap a)
                (+ (cap a) (+ " " (ujoin (cup a)))))
   ; the many-file banner head and tail share: none before the first, a blank between
   (uhdr first f) (? first (+ "==> " (+ f " <==\n")) (+ "\n==> " (+ f " <==\n")))
   ; the two pure line clips (lawed in law.l)
   (uhead n t) (: ls (lines t) (unlines (? (< n (tally ls)) (take n ls) ls)))
   (utail n t) (: ls (lines t) k (tally ls) (unlines (? (< n k) (drop (- k n) ls) ls)))
   ; the wc counter: text -> (lines words bytes), a word a maximal ink run
   (ucount t)
    (: n (tally t)
       (ws? c) (|| (= c 32) (&& (< 8 c) (< c 14)))
       (go k inw l w) (? (<= n k) (L l w n)
                         (: c (t k)
                            (? (ws? c) (go (+ k 1) 0 (? (= c 10) (+ l 1) l) w)
                               (go (+ k 1) 1 l (? inw w (+ w 1))))))
       (go 0 0 0 0))
   ; the two pure path clips (basename NAME [SUFFIX] / dirname NAME; lawed in law.l)
   (ubase p sfx)
    (: (e k) (? (&& (< 0 k) (= (p (- k 1)) 47)) (e (- k 1)) k)
       e0 (e (tally p))
       (? (= e0 0) (? (< 0 (tally p)) "/" "")
          (: (b k) (? (&& (< 0 k) (! (= (p (- k 1)) 47))) (b (- k 1)) k)
             s (snip p (b e0) e0)
             m (tally sfx) n (tally s)
             (? (&& (< 0 m) (&& (< m n) (= (snip s (- n m) n) sfx)))
                (snip s 0 (- n m)) s))))
   (udir p)
    (: (e k) (? (&& (< 0 k) (= (p (- k 1)) 47)) (e (- k 1)) k)
       e0 (e (tally p))
       (? (= e0 0) (? (< 0 (tally p)) "/" ".")
          (: (b k) (? (&& (< 0 k) (! (= (p (- k 1)) 47))) (b (- k 1)) k)
             b0 (b e0)
             (? (= b0 0) "."
                (: z (e b0) (? (= z 0) "/" (snip p 0 z)))))))

   ; -- cat: files (or -) onto out, verbatim --
   (cat-main as)
    (: (one f ok) (? (= f "-") (: _ (puts (slurp in)) ok)
                     (: r (uread f)
                        (? (two? r) (: _ (puts (caup r)) ok)
                           (: _ (say err (+ "cat: cannot open " f)) _ (put err 10) 0))))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok))
                    (: _ (flush out) (nap (? ok 0 1))))
       (? (two? as) (go as 1) (: _ (puts (slurp in)) _ (flush out) (nap 0))))

   ; -- echo: the args back; -n holds the newline --
   (echo-main as)
    (? (&& (two? as) (= (cap as) "-n"))
       (: _ (say out (ujoin (cup as))) _ (flush out) (nap 0))
       (: _ (say out (ujoin as)) _ (put out 10) _ (flush out) (nap 0)))

   ; -- head and tail: one driver, two clips; -n N (10 the default) --
   (uclip who clip as)
    (: nr (? (&& (two? as) (= (cap as) "-n"))
             (? (two? (cup as)) (L (uatoi (caup as)) (cuup as))
                (udie 2 (+ who ": -n wants a count")))
             (L 10 as))
       n (cap nr) fs (caup nr)
       many (&& (two? fs) (two? (cup fs)))
       (one f first ok)
        (: r (? (= f "-") (L 1 (slurp in)) (uread f))
           (? (two? r)
              (: _ (? many (say out (uhdr first (? (= f "-") "standard input" f))) ())
                 _ (say out (clip n (caup r)))
                 ok)
              (: _ (say err (+ who (+ ": cannot open " f))) _ (put err 10) 0)))
       (go a first ok) (? (two? a) (go (cup a) 0 (one (cap a) first ok))
                          (: _ (flush out) (nap (? ok 0 1))))
       (? (two? fs) (go fs 1 1)
          (: _ (say out (clip n (slurp in))) _ (flush out) (nap 0))))
   (head-main as) (uclip "head" uhead as)
   (tail-main as) (uclip "tail" utail as)

   ; -- wc: lines, words, bytes (flags pick; bare wc reads all three) --
   (wc-main as)
    (: (fl a l w c) (? (! (two? a)) (L l w c a)
                       (= (cap a) "-l") (fl (cup a) 1 w c)
                       (= (cap a) "-w") (fl (cup a) l 1 c)
                       (= (cap a) "-c") (fl (cup a) l w 1)
                       (L l w c a))
       p (fl as 0 0 0)
       none (! (|| (cap p) (|| (caup p) (caup (cup p)))))
       l? (? none 1 (cap p)) w? (? none 1 (caup p)) c? (? none 1 (caup (cup p)))
       fs (caup (cuup p))
       (c3 x) (cap (cuup x))
       ; read every input up front: a row is (name (l w b)), name () for stdin
       (rd a acc ok)
        (? (! (two? a)) (L (rev acc) ok)
           (: f (cap a)
              r (? (= f "-") (L 1 (slurp in)) (uread f))
              (? (two? r) (rd (cup a) (link (L f (ucount (caup r))) acc) ok)
                 (: _ (say err (+ "wc: cannot open " f)) _ (put err 10)
                    (rd (cup a) acc 0)))))
       ro (? (two? fs) (rd fs () 1) (L (L (L () (ucount (slurp in)))) 1))
       rows (cap ro) ok (caup ro)
       (sum sel a acc) (? (two? a) (sum sel (cup a) (+ acc (sel (caup (cap a))))) acc)
       tl (sum cap rows 0) tw (sum caup rows 0) tb (sum c3 rows 0)
       wdt (tally (show tb))                        ; the GNU face: pad to the byte total
       (fmt cnt) (: a (? c? (L (upad wdt (show (c3 cnt)))) ())
                    a (? w? (link (upad wdt (show (caup cnt))) a) a)
                    a (? l? (link (upad wdt (show (cap cnt))) a) a)
                    (ujoin a))
       (emit rs) (? (! (two? rs)) ()
                    (: row (cap rs)
                       _ (say out (fmt (caup row)))
                       _ (? (! (cap row)) () (say out (+ " " (cap row))))
                       _ (put out 10)
                       (emit (cup rs))))
       _ (emit rows)
       _ (? (&& (two? rows) (two? (cup rows)))
            (: _ (say out (fmt (L tl tw tb))) _ (say out " total") (put out 10)) ())
       _ (flush out) (nap (? ok 0 1)))

   ; -- sort: the prel sort IS byte order (the LC_ALL=C face); -r reverses, -u keeps firsts --
   (sort-main as)
    (: (fl a r u) (? (! (two? a)) (L r u a)
                     (= (cap a) "-r") (fl (cup a) 1 u)
                     (= (cap a) "-u") (fl (cup a) r 1)
                     (L r u a))
       p (fl as 0 0)
       r? (cap p) u? (caup p) fs (caup (cup p))
       (rd a acc) (? (! (two? a)) acc
                     (: f (cap a)
                        t (? (= f "-") (slurp in)
                             (: x (uread f) (? (two? x) (caup x)
                                               (udie 2 (+ "sort: cannot open " f)))))
                        (rd (cup a) (+ acc (lines t)))))
       (ded a) (? (! (two? a)) ()
                  (! (two? (cup a))) a
                  (= (cap a) (caup a)) (ded (cup a))
                  (link (cap a) (ded (cup a))))
       s1 (sort (? (two? fs) (rd fs ()) (lines (slurp in))))
       s2 (? u? (ded s1) s1)
       _ (say out (unlines (? r? (rev s2) s2)))
       _ (flush out) (nap 0))

   ; -- uniq: adjacent runs to their firsts; -c wears the run count, width 7 --
   (uniq-main as)
    (: c? (&& (two? as) (= (cap as) "-c"))
       fs (? c? (cup as) as)
       t (? (two? fs)
            (: x (uread (cap fs)) (? (two? x) (caup x)
                                     (udie 2 (+ "uniq: cannot open " (cap fs)))))
            (slurp in))
       (emit line cnt) (: _ (? c? (say out (+ (upad 7 (show cnt)) " ")) ())
                          _ (say out line) (put out 10))
       (go a prev cnt)
        (? (! (two? a)) (? (< 0 cnt) (emit prev cnt) ())
           (= cnt 0) (go (cup a) (cap a) 1)
           (= (cap a) prev) (go (cup a) prev (+ cnt 1))
           (: _ (emit prev cnt) (go (cup a) (cap a) 1)))
       _ (go (lines t) () 0)
       _ (flush out) (nap 0))

   ; -- tee: stdin onto out AND every file (-a appends) --
   (tee-main as)
    (: a? (&& (two? as) (= (cap as) "-a"))
       fs (? a? (cup as) as)
       t (slurp in)
       (one f ok) (: q (open f (? a? "a" "w"))
                     (? q (: _ (say q t) _ (close q) ok)
                        (: _ (say err (+ "tee: cannot open " f)) _ (put err 10) 0)))
       (go a ok) (? (two? a) (go (cup a) (one (cap a) ok)) ok)
       ok (go fs 1)
       _ (puts t) _ (flush out) (nap (? ok 0 1)))

   ; -- seq: FIRST INCR LAST, one a line (one and two args fill in the 1s) --
   (seq-main as)
    (: n (tally as)
       trip (? (= n 1) (L 1 1 (uatoi (cap as)))
               (= n 2) (L (uatoi (cap as)) 1 (uatoi (caup as)))
               (= n 3) (L (uatoi (cap as)) (uatoi (caup as)) (uatoi (caup (cup as))))
               (udie 2 "usage: seq [FIRST [INCR]] LAST"))
       a (cap trip) d (caup trip) z (caup (cup trip))
       _ (? (= d 0) (udie 2 "seq: increment must not be 0") ())
       (go i) (? (? (< 0 d) (<= i z) (<= z i))
                 (: _ (say out (show i)) _ (put out 10) (go (+ i d)))
                 ())
       _ (go a) _ (flush out) (nap 0))

   ; -- yes: the affirmative, forever (args override the y) --
   (yes-main as)
    (: w (? (two? as) (ujoin as) "y")
       (go _) (: _ (say out w) _ (put out 10) _ (flush out) (go ()))
       (go ()))

   ; -- true and false: the two exit codes, nothing else --
   (true-main _) (nap 0)
   (false-main _) (nap 1)

   ; -- basename and dirname: the two path clips --
   (basename-main as)
    (? (! (two? as)) (udie 2 "usage: basename NAME [SUFFIX]")
       (: _ (say out (ubase (cap as) (? (two? (cup as)) (caup as) "")))
          _ (put out 10) _ (flush out) (nap 0)))
   (dirname-main as)
    (? (! (two? as)) (udie 2 "usage: dirname NAME")
       (: _ (say out (udir (cap as))) _ (put out 10) _ (flush out) (nap 0))))
