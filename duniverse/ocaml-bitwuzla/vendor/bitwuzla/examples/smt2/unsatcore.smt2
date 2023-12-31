(set-logic ALL)
(set-option :produce-unsat-cores true)
(declare-const x0 (_ BitVec 4))
(declare-const x1 (_ BitVec 2))
(declare-const x2 (_ BitVec 2))
(declare-const x3 (_ BitVec 2))
(declare-const x4 Float16)
(define-fun f0 ((a Float16)) Bool (fp.gt a (_ +zero 5 11)))
(define-fun f1 ((a Float16)) (_ BitVec 4) (ite (f0 a) x0 #b0000))
(define-fun f2 ((a Float16)) (_ BitVec 2) ((_ extract 1 0) (f1 a)))
(assert (! (bvult x2 (f2 (_ +zero 5 11))) :named assertion0))
(assert (! (= x1 x2 x3) :named assertion1))
(assert (!(= x4 ((_ to_fp_unsigned 5 11) RNE x3)) :named assertion2))
(check-sat)
(get-unsat-core)
