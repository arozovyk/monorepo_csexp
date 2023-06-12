(set-logic QF_FPLRA)
(set-option :produce-models true)
(set-info :status sat)
(declare-const x Float16)
(declare-const y Float16)
(assert (= (fp.add RNA x y) ((_ to_fp 5 11) RNA 0.0117749388721091)))
(check-sat)
(get-value (((_ to_fp 5 11) RNA 0.1)))
