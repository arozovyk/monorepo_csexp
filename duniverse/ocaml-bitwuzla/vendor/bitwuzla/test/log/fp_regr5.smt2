(set-logic QF_BVFP)
(define-fun cast_fp64_sint16 ((f Float64)) (_ BitVec 32) (_ bv0 32))
(declare-fun invariance_property$$0 () Bool)
(push 1)
(assert invariance_property$$0)
(assert false)
(check-sat)
(pop 1)
(assert invariance_property$$0)
(check-sat)
(exit)
