(set-info :status sat)
(declare-fun P (Bool) Bool)
(declare-fun Q (Bool Bool Bool Bool) Bool)
(assert (forall ((x Bool)) (or (P true) (forall ((x Bool)) (exists ((y Bool)) (and (P false) (Q false x y false)))))))
(check-sat)
