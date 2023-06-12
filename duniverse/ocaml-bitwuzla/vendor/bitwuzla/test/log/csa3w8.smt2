(set-logic QF_BV)
(declare-fun a () (_ BitVec 8))
(declare-fun b () (_ BitVec 8))
(declare-fun c () (_ BitVec 8))
(declare-fun x () (_ BitVec 8))
(assert (= x (bvadd (bvadd a b) c)))
(declare-fun c0 () (_ BitVec 8))
(declare-fun s0 () (_ BitVec 8))
(assert (= s0 (bvxor a b)))
(assert (= c0 (concat ((_ extract 6 0)(bvand a b))(_ bv0 1))))
(declare-fun c1 () (_ BitVec 8))
(declare-fun s1 () (_ BitVec 8))
(assert (= s1 (bvxor s0 (bvxor c0 c))))
(assert (= c1 (concat ((_ extract 6 0)
                (bvor (bvand s0 c0) (bvor (bvand s0 c) (bvand c0 c))))
		   (_ bv0 1))))
(declare-fun y () (_ BitVec 8))
(assert (= y (bvadd s1 c1)))
(assert (distinct x y))
(check-sat)
(exit)
