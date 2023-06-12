#include <bitwuzla/bitwuzla.h>
#include <stdio.h>

int
main()
{
  // First, create a Bitwuzla instance.
  Bitwuzla *bzla = bitwuzla_new();
  // Then, enable incremental solving extraction.
  // Note: Incremental solving is disabled by default.
  //       Unsat assumptions extraction is enabled by default and cannot be
  //       disabled.
  bitwuzla_set_option(bzla, BITWUZLA_OPT_INCREMENTAL, 1);

  // Create Boolean sort.
  BitwuzlaSort *sortbool = bitwuzla_mk_bool_sort(bzla);
  // Create a bit-vector sort of size 2.
  BitwuzlaSort *sortbv2 = bitwuzla_mk_bv_sort(bzla, 2);
  // Create a bit-vector sort of size 4.
  BitwuzlaSort *sortbv4 = bitwuzla_mk_bv_sort(bzla, 4);
  // Create Float16 floatinf-point sort.
  BitwuzlaSort *sortfp16 = bitwuzla_mk_fp_sort(bzla, 5, 11);

  // Create bit-vector variables.
  // (declare-const x0 (_ BitVec 4))
  BitwuzlaTerm *x0 = bitwuzla_mk_const(bzla, sortbv4, "x0");
  // (declare-const x1 (_ BitVec 2))
  BitwuzlaTerm *x1 = bitwuzla_mk_const(bzla, sortbv2, "x1");
  // (declare-const x2 (_ BitVec 2))
  BitwuzlaTerm *x2 = bitwuzla_mk_const(bzla, sortbv2, "x2");
  // (declare-const x3 (_ BitVec 2))
  BitwuzlaTerm *x3 = bitwuzla_mk_const(bzla, sortbv2, "x3");
  // (declare-const x4 Float16)
  BitwuzlaTerm *x4 = bitwuzla_mk_const(bzla, sortfp16, "x4");

  // Create FP positive zero.
  BitwuzlaTerm *fpzero = bitwuzla_mk_fp_pos_zero(bzla, sortfp16);
  // Create BV zero of size 4.
  BitwuzlaTerm *bvzero = bitwuzla_mk_bv_zero(bzla, sortbv4);

  // (define-fun f0 ((a Float16)) Bool (fp.gt a (_ +zero 5 11)))
  BitwuzlaTerm *a_f0 = bitwuzla_mk_var(bzla, sortfp16, "a_f0");
  BitwuzlaTerm *f0   = bitwuzla_mk_term2(
      bzla,
      BITWUZLA_KIND_LAMBDA,
      a_f0,
      bitwuzla_mk_term2(bzla, BITWUZLA_KIND_FP_GT, a_f0, fpzero));

  // (define-fun f1 ((a Float16)) (_ BitVec 4) (ite (f0 a) x0 #b0000))
  BitwuzlaTerm *a_f1 = bitwuzla_mk_var(bzla, sortfp16, "a_f1");
  BitwuzlaTerm *f1   = bitwuzla_mk_term2(
      bzla,
      BITWUZLA_KIND_LAMBDA,
      a_f1,
      bitwuzla_mk_term3(bzla,
                        BITWUZLA_KIND_ITE,
                        bitwuzla_mk_term2(bzla, BITWUZLA_KIND_APPLY, f0, a_f1),
                        x0,
                        bvzero));

  // (define-fun f2 ((a Float16)) (_ BitVec 2) ((_ extract 1 0) (f1 a)))
  BitwuzlaTerm *a_f2 = bitwuzla_mk_var(bzla, sortfp16, "a_f2");
  BitwuzlaTerm *f2   = bitwuzla_mk_term2(
      bzla,
      BITWUZLA_KIND_LAMBDA,
      a_f2,
      bitwuzla_mk_term1_indexed2(
          bzla,
          BITWUZLA_KIND_BV_EXTRACT,
          bitwuzla_mk_term2(bzla, BITWUZLA_KIND_APPLY, f1, a_f2),
          1,
          0));

  // (assert (! (bvult x2 (f2 (_ +zero 5 11))) :named a0))
  BitwuzlaTerm *assumption0 = bitwuzla_mk_term2(
      bzla,
      BITWUZLA_KIND_BV_ULT,
      x2,
      bitwuzla_mk_term2(bzla, BITWUZLA_KIND_APPLY, f2, fpzero));
  bitwuzla_term_set_symbol(assumption0, "assumption0");
  bitwuzla_assume(bzla, assumption0);

  // (assert (! (= x1 x2 x3) :named a1))
  BitwuzlaTerm *assumption1 =
      bitwuzla_mk_term3(bzla, BITWUZLA_KIND_EQUAL, x1, x2, x3);
  bitwuzla_term_set_symbol(assumption1, "assumption1");
  bitwuzla_assume(bzla, assumption1);

  // (assert (!(= x4 ((_ to_fp_unsigned 5 11) RNE x3)) :named a2))
  BitwuzlaTerm *assumption2 = bitwuzla_mk_term2(
      bzla,
      BITWUZLA_KIND_EQUAL,
      x4,
      bitwuzla_mk_term2_indexed2(bzla,
                                 BITWUZLA_KIND_FP_TO_FP_FROM_UBV,
                                 bitwuzla_mk_rm_value(bzla, BITWUZLA_RM_RNE),
                                 x3,
                                 5,
                                 11));
  bitwuzla_term_set_symbol(assumption2, "assumption2");
  bitwuzla_assume(bzla, assumption2);

  // (check-sat-assuming (assumption0 assumption1 assumption2))
  BitwuzlaResult result = bitwuzla_check_sat(bzla);
  printf("Expect: unsat\n");
  printf("Bitwuzla: %s\n",
         result == BITWUZLA_SAT
             ? "sat"
             : (result == BITWUZLA_UNSAT ? "unsat" : "unknown"));

  // (get-unsat-assumptions)
  size_t unsat_assumptions_size;
  BitwuzlaTerm **unsat_assumptions =
      bitwuzla_get_unsat_assumptions(bzla, &unsat_assumptions_size);
  printf("Unsat Assumptions: {");
  for (uint32_t i = 0; i < unsat_assumptions_size; ++i)
  {
    printf(" %s", bitwuzla_term_get_symbol(unsat_assumptions[i]));
  }
  printf(" }\n");

  // Finally, delete the Bitwuzla instance.
  bitwuzla_delete(bzla);
}
