(declare-const x Bool)
(declare-const x8 RoundingMode)
(assert (forall ((x6 RoundingMode)) (distinct x (forall ((x7 Bool)) (= x7 (distinct x7 (distinct x8 x6)))))))
(check-sat)
