(set-logic QF_FP)
(define-fun x () Float64 (_ +zero 11 53))
(define-fun y () Float64 (_ -zero 11 53))
(assert (= (fp.min x y) x))
(assert (= (fp.min y x) x))
(assert (= (fp.min x y) y))
(assert (= (fp.min y x) y))
(check-sat)

