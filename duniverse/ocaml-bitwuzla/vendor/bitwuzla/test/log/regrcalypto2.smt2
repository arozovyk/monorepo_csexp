(set-logic QF_BV)
(set-info :smt-lib-version 2.0)
(declare-fun E_27142 ()(_ BitVec 32))
(declare-fun E_27154 ()(_ BitVec 32))
(declare-fun E_27149 ()(_ BitVec 32))
(declare-fun E_27148 ()(_ BitVec 32))
(declare-fun E_27150 ()(_ BitVec 32))
(declare-fun E_27147 ()(_ BitVec 32))
(declare-fun E_27151 ()(_ BitVec 1))
(declare-fun E_27152 ()(_ BitVec 32))
(declare-fun E_27144 ()(_ BitVec 32))
(declare-fun E_27145 ()(_ BitVec 32))
(declare-fun E_27143 ()(_ BitVec 32))
(declare-fun E_27146 ()(_ BitVec 32))
(declare-fun E_27153 ()(_ BitVec 1))
(declare-fun E_27139 ()(_ BitVec 1))
(declare-fun E_27137 ()(_ BitVec 3))
(declare-fun E_27136 ()(_ BitVec 2))
(declare-fun E_27138 ()(_ BitVec 3))
(declare-fun E_27156 ()(_ BitVec 1))
(declare-fun E_27140 ()(_ BitVec 3))
(declare-fun E_27141 ()(_ BitVec 1))
(declare-fun E_27134 ()(_ BitVec 1))
(declare-fun E_27132 ()(_ BitVec 1))
(declare-fun E_27129 ()(_ BitVec 1))
(declare-fun E_27130 ()(_ BitVec 1))
(declare-fun E_27123 ()(_ BitVec 1))
(declare-fun E_27124 ()(_ BitVec 1))
(declare-fun E_27155 ()(_ BitVec 1))
(declare-fun E_27125 ()(_ BitVec 1))
(declare-fun E_27126 ()(_ BitVec 32))
(declare-fun E_27120 ()(_ BitVec 1))
(declare-fun E_27121 ()(_ BitVec 32))
(declare-fun E_27122 ()(_ BitVec 32))
(declare-fun E_27127 ()(_ BitVec 32))
(declare-fun E_27128 ()(_ BitVec 32))
(declare-fun E_27131 ()(_ BitVec 32))
(declare-fun E_27133 ()(_ BitVec 32))
(declare-fun E_27135 ()(_ BitVec 32))
(assert  (=  ((_ extract 31 0)(bvsub  ((_ zero_extend 1) E_27149) ((_ sign_extend 1) E_27148)))  E_27150))
(assert  (=  ((_ extract 31 0)(bvadd  ((_ zero_extend 1) E_27149) ((_ sign_extend 1) E_27148)))  E_27147))
(assert  (=  (ite  (=  (_ bv1 1)  E_27151)  E_27147  E_27150)  E_27152))
(assert  (=  (bvor   E_27144  E_27148)  E_27145))
(assert  (=  (bvand   E_27144  E_27148)  E_27143))
(assert  (=  (ite  (=  (_ bv1 1)  E_27151)  E_27143  E_27145)  E_27146))
(assert  (=  (ite  (=  (_ bv1 1)  E_27153)  E_27146  E_27152)  E_27154))
(assert  (=  (bvnot   E_27151)  E_27139))
(assert  (=   #b100  E_27137))
(assert  (=   #b10  E_27136))
(assert  (=  (ite  (=  (_ bv1 1)  E_27153) ((_ zero_extend 1) E_27136)  E_27137)  E_27138))
(assert  (=   #b1  E_27156))
(assert  (=  (ite  (=  (_ bv1 1)  E_27139) ((_ zero_extend 2) E_27156)  E_27138)  E_27140))
(assert  (=  ((_ extract 1 1) E_27140)  E_27141))
(assert  (=  (bvand   E_27139  E_27153)  E_27134))
(assert  (=  ((_ extract 2 2) E_27140)  E_27132))
(assert  (=  (bvnot   E_27153)  E_27129))
(assert  (=  (bvand   E_27139  E_27129)  E_27130))
(assert  (=  (ite  (=  (_ bv1 1)  E_27130)  E_27156  E_27123)  E_27124))
(assert  (=   #b0  E_27155))
(assert  (=  (ite  (=  (_ bv1 1)  E_27132)  E_27155  E_27124)  E_27125))
(assert  (=  (bvadd   E_27149 ((_ zero_extend 31) E_27125))  E_27126))
(assert  (=   #b1  E_27120))
(assert  (=  (bvsub  ((_ sign_extend 31) E_27120)  E_27148)  E_27121))
(assert  (=  (ite  (=  (_ bv1 1)  E_27125)  E_27121  E_27148)  E_27122))
(assert  (=  (bvadd   E_27126  E_27122)  E_27127))
(assert  (=  (ite  (=  (_ bv1 1)  E_27130)  E_27127  E_27128)  E_27131))
(assert  (=  (ite  (=  (_ bv1 1)  E_27132)  E_27127  E_27131)  E_27133))
(assert  (=  (ite  (=  (_ bv1 1)  E_27134)  E_27145  E_27133)  E_27135))
(assert  (=  (ite  (=  (_ bv1 1)  E_27141)  E_27143  E_27135)  E_27142))
(assert  (=  (bvcomp   E_27142  E_27154) (_ bv0 1)))
(check-sat)
(exit)
