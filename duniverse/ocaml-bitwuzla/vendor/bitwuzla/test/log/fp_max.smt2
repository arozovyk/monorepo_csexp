(set-logic QF_FP)
(define-fun x () Float64 (_ +zero 11 53))
(define-fun y () Float64 (_ -zero 11 53))
(assert (= (fp.max x y) x))
(assert (= (fp.max y x) x))
(assert (= (fp.max x y) y))
(assert (= (fp.max y x) y))
(check-sat)

