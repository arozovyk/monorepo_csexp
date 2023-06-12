/*  Bitwuzla: Satisfiability Modulo Theories (SMT) solver.
 *
 *  Copyright (C) 2015-2017 Mathias Preiner.
 *  Copyright (C) 2017 Aina Niemetz.
 *
 *  This file is part of Bitwuzla.
 *  See COPYING for more information on using this software.
 */

extern "C" {
#include "bzlaslvquant.h"

#include "bzlabeta.h"
#include "bzlabv.h"
#include "bzlaclone.h"
#include "bzlacore.h"
#include "bzlaexp.h"
#include "bzlamodel.h"
#include "bzlaprintmodel.h"
#include "bzlaslvfun.h"
#include "dumper/bzladumpsmt.h"
#include "utils/bzlaabort.h"
#include "utils/bzlahashint.h"
#include "utils/bzlahashptr.h"
#include "utils/bzlanodeiter.h"
#include "utils/bzlautil.h"
}

#include <algorithm>
#include <cstdarg>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include <unordered_map>
#include <unordered_set>
#include <vector>

#include "bzlasynthterm.h"

namespace std {
template <>
struct hash<std::pair<BzlaNode *, BzlaNode *>>
{
  size_t operator()(const std::pair<BzlaNode *, BzlaNode *> &p) const
  {
    size_t hash = bzla_node_get_id(p.first);
    if (p.second)
    {
      hash += bzla_node_get_id(p.second);
    }
    return hash;
  }
};

#if 0
  template<>
  struct hash<BzlaNode *>
  {
    size_t operator()(const BzlaNode * n) const
    {
      return bzla_node_get_id(n);
    }
  };
#endif
}  // namespace std

namespace bzla {

/*------------------------------------------------------------------------*/

template <typename T>
using NodeMap = std::unordered_map<BzlaNode *, T>;
using NodeSet = std::unordered_set<BzlaNode *>;

/*------------------------------------------------------------------------*/

std::ostream &
operator<<(std::ostream &out, BzlaNode *n)
{
  out << bzla_util_node2string(n);
  return out;
}

/*------------------------------------------------------------------------*/

//#define QLOG

#ifdef QLOG

namespace {

void
qlog(const char *fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  vfprintf(stdout, fmt, ap);
  fflush(stdout);
  va_end(ap);
}

void
qlog_print_synth_table(Bzla *bzla,
                       const std::vector<BzlaNode *> &inputs,
                       const std::vector<BzlaBitVectorTuple *> &values_in,
                       const std::vector<BzlaBitVector *> &values_out,
                       const std::vector<BzlaNode *> &consts)
{
  assert(values_in.size() == values_out.size());
  for (size_t i = 0; i < values_in.size(); ++i)
  {
    auto bvt = values_in[i];
    std::stringstream ss, ssin;

    for (size_t j = 0; j < bvt->arity; ++j)
    {
      char *bv = bzla_bv_to_char(bzla->mm, bvt->bv[j]);
      ss << bv << " ";
      ssin << std::setw(strlen(bv)) << inputs[j] << " ";
      if (j < bvt->arity - 1)
      {
        ssin << "| ";
      }
      bzla_mem_freestr(bzla->mm, bv);
    }

    if (i == 0)
    {
      std::cout << ssin.str() << std::endl;
    }

    char *bv = bzla_bv_to_char(bzla->mm, values_out[i]);
    ss << "-> " << bv << "\n";
    bzla_mem_freestr(bzla->mm, bv);
    std::cout << ss.str();
  }

  if (!consts.empty())
  {
    std::cout << "Consts:" << std::endl;
    for (auto c : consts)
    {
      std::cout << "  " << c << std::endl;
    }
  }
}

}  // namespace

#else

#define qlog(...)        \
  while (false)          \
  {                      \
    printf(__VA_ARGS__); \
  }

#define qlog_print_synth_table(bzla, inputs, in, out, consts)

#endif

/*------------------------------------------------------------------------*/
/* Solver State                                                           */
/*------------------------------------------------------------------------*/

struct SynthData
{
  SynthData(BzlaMemMgr *mm) : d_mm(mm) {}
  ~SynthData();

  BzlaMemMgr *d_mm;
  std::vector<BzlaBitVectorTuple *> d_values_in;
  std::vector<BzlaBitVector *> d_values_out;
};

SynthData::~SynthData()
{
  for (BzlaBitVectorTuple *bvtup : d_values_in)
  {
    bzla_bv_free_tuple(d_mm, bvtup);
  }
  for (BzlaBitVector *bv : d_values_out)
  {
    bzla_bv_free(d_mm, bv);
  }
}

enum class LemmaKind
{
  COUNTEREXAMPLE,
  MBQI_INST,
  SKOLEMIZATION,
  SYNTH_INST,
  VALUE_INST
};

static const char *
to_string(LemmaKind k)
{
  switch (k)
  {
    case LemmaKind::COUNTEREXAMPLE: return "COUNTEREXAMPLE";
    case LemmaKind::MBQI_INST: return "MBQI_INST";
    case LemmaKind::SKOLEMIZATION: return "SKOLEMIZATION";
    case LemmaKind::VALUE_INST: return "VALUE_INST";
    case LemmaKind::SYNTH_INST: return "SYNTH_INST";
    default: assert(false); return "UNKNOWN";
  }
}

class QuantSolverState
{
 public:
  QuantSolverState(Bzla *bzla);
  ~QuantSolverState();

  /** Reset state for next check-sat call. */
  void reset();

  void get_active_quantifiers();
  bool is_forall(BzlaNode *q);
  bool is_exists(BzlaNode *q);
  bool check_active_quantifiers();
  BzlaSolverResult check_ground_formulas();

  void set_inactive(BzlaNode *q);
  bool is_inactive(BzlaNode *q);

  void compute_variable_dependencies_aux(BzlaNode *q,
                                         std::vector<BzlaNode *> &free_vars);
  void compute_variable_dependencies(const std::vector<BzlaNode *> quantifiers);

  /* Collect values and constants in the formula and populate d_value_map and
   * d_const_map. */
  void collect_info(std::vector<BzlaNode *> &quantifiers);

  /** Add new instance of `q_orig` and track dependencies. */
  void add_instance(BzlaNode *q_orig,
                    BzlaNode *q_inst,
                    const NodeMap<BzlaNode *> &substs);

  /** Find original instance of quantifier `q`. */
  BzlaNode *find_original_instance(BzlaNode *q);
  BzlaNode *find_parent(BzlaNode *q);

  /** Record instance `q_inst` of quantified formula `q_orig`. */
  void record_instance(BzlaNode *q_inst, BzlaNode *q_orig);

  BzlaNode *get_skolem(BzlaNode *q);

  BzlaNode *get_inst_constant(BzlaNode *q);
  BzlaNode *skolemize(BzlaNode *q);
  BzlaNode *get_skolemization_lemma(BzlaNode *q);
  bool added_skolemization_lemma(BzlaNode *q);

  /**
   * Generate counterexample lemma.
   *
   * Creates the following lemma for a quantifier q := \forall x . P(x):
   *
   * k => \not P(ic(x)), where k is a fresh constant introduced for q and ic(x)
   * is the instantiation constant for x.
   */
  BzlaNode *get_ce_lemma(BzlaNode *q);

  /**
   * Check whether a counterexample lemmas was already added for quantifier q.
   */
  bool added_ce_lemma(BzlaNode *q);

  /** Returns the counterexample literal for given quantifier. */
  BzlaNode *get_ce_literal(BzlaNode *q);

  BzlaNode *instantiate(BzlaNode *q, const NodeMap<BzlaNode *> &substs);

  bool add_lemma(BzlaNode *lem, LemmaKind k);
  void assert_lemmas();
  void add_value_instantiation_lemma(BzlaNode *q);

  bool added_new_lemmas() const;

  BzlaSolverResult check_sat_ground();
  void generate_model_ground();
  void reset_assumptions();
  void pop_assumption();
  bool assume(BzlaNode *n);
  void save_assumptions();

  void get_fun_model(BzlaNode *sk_fun,
                     std::vector<BzlaBitVectorTuple *> &values_in,
                     std::vector<BzlaBitVector *> &values_out);
  void synthesize_terms();
  void store_synthesized_term(BzlaNode *sk, BzlaNode *term);
  void synthesize_qi(BzlaNode *q);
  void mbqi(BzlaNode *q);

  void print_statistics() const;
  void print_time_statistics() const;

  struct
  {
    uint64_t num_ground_checks            = 0;
    uint64_t num_ground_checks_iterations = 0;
    uint64_t num_counterexample_checks    = 0;
    uint64_t num_value_inst_lemmas        = 0;
    uint64_t num_synth_qi_lemmas          = 0;
    uint64_t num_mbqi_lemmas              = 0;
    uint64_t num_skolemization_lemmas     = 0;
    uint64_t num_ce_lemmas                = 0;

    double time_check_sat             = 0;
    double time_check_ground          = 0;
    double time_synthesize_terms      = 0;
    double time_check_counterexamples = 0;
    double time_get_active            = 0;
  } d_statistics;

 private:
  Bzla *d_bzla;

  /**
   * Contains currently active quantifiers (populatd by get_active_quantifiers).
   */
  std::vector<BzlaNode *> d_active_quantifiers;

  NodeMap<bool> d_quantifiers;

  NodeSet d_inactive_quantifiers;

  NodeMap<std::vector<BzlaNode *>> d_deps;
  /**
   * Stores all instantiations and maps an instantiated quantifier back to the
   * original quantifier.
   */
  NodeMap<BzlaNode *> d_instantiations;

  /* Maps quantifier to introduced skolem. */
  std::unordered_map<std::pair<BzlaNode *, BzlaNode *>, BzlaNode *> d_skolems;

  /* Stores all Skolem UFs for which we can use synthesis.
   * Currently supported are bit-vector UFs, but not FP. */
  NodeSet d_use_synth;

  /* Maps quantifier to instantiation constant. */
  NodeMap<BzlaNode *> d_instantiation_constants;
  /* Cache for added skolemization lemmas. */
  NodeMap<BzlaNode *> d_skolemization_lemmas;
  /* Cache for CE lemmas. */
  NodeMap<BzlaNode *> d_ce_lemmas;
  /* Cache for CE literals. */
  NodeMap<BzlaNode *> d_ce_literals;
  /* Cache of added lemmas. */
  NodeMap<LemmaKind> d_lemma_cache;
  std::vector<BzlaNode *> d_lemmas;
  /* Maps Skolem constant/function to synthesized term. */
  NodeMap<BzlaNode *> d_synthesized_terms;

  bool d_added_lemma;
  /* Flag indicating whether the last ground check was satisfiable with all
   * counterexample literals assumed. Used for BZLA_QUANT_MODE_EAGER_REUSE. */
  bool d_last_ground_check_ok = false;

  /* Assumption stack */
  std::vector<BzlaNode *> d_assumptions;
  std::vector<BzlaNode *> d_assumptions_simp;

  /**
   * Maps sort ids to values of given sort found by traversing root
   * constraints. Populated by collect_info().
   */
  std::unordered_map<BzlaSortId, std::vector<BzlaNode *>> d_value_map;

  /**
   * Maps sort ids to constants of given sort found by traversing root
   * constraints. Populated by collect_info().
   */
  std::unordered_map<BzlaSortId, std::vector<BzlaNode *>> d_const_map;

  /**
   * Maps sort ids to ground terms of given sort found by traversing root
   * constraints. Populated by collect_info().
   */
  std::unordered_map<BzlaSortId, std::vector<BzlaNode *>> d_term_map;

  NodeSet d_constants;

  std::unordered_map<BzlaNode *, SynthData> d_synth_qi_data;

  bool d_opt_synth_sk;
  bool d_opt_synth_qi;
  bool d_opt_skolem_uf;
  bool d_opt_eager_skolem;
  bool d_opt_mbqi;
  BzlaOptQuantMode d_opt_mode;
};

QuantSolverState::QuantSolverState(Bzla *bzla)
    : d_bzla(bzla),
      d_opt_synth_sk(bzla_opt_get(bzla, BZLA_OPT_QUANT_SYNTH_SK) == 1),
      d_opt_synth_qi(bzla_opt_get(bzla, BZLA_OPT_QUANT_SYNTH_QI) == 1),
      d_opt_skolem_uf(bzla_opt_get(bzla, BZLA_OPT_QUANT_SKOLEM_UF) == 1),
      d_opt_eager_skolem(bzla_opt_get(bzla, BZLA_OPT_QUANT_EAGER_SKOLEM) == 1),
      d_opt_mbqi(bzla_opt_get(bzla, BZLA_OPT_QUANT_MBQI) == 1),
      d_opt_mode(static_cast<BzlaOptQuantMode>(
          bzla_opt_get(bzla, BZLA_OPT_QUANT_MODE))){};

QuantSolverState::~QuantSolverState()
{
  for (BzlaNode *q : d_inactive_quantifiers)
  {
    bzla_node_release(d_bzla, q);
  }

  for (auto &p : d_deps)
  {
    bzla_node_release(d_bzla, p.first);
    for (BzlaNode *n : p.second)
    {
      bzla_node_release(d_bzla, n);
    }
  }

  for (auto [qi, q] : d_instantiations)
  {
    bzla_node_release(d_bzla, qi);
    bzla_node_release(d_bzla, q);
  }

  for (auto [p, s] : d_skolems)
  {
    bzla_node_release(d_bzla, p.first);
    if (p.second != nullptr)
    {
      bzla_node_release(d_bzla, p.second);
    }
    bzla_node_release(d_bzla, s);
  }

  for (auto [q, c] : d_instantiation_constants)
  {
    bzla_node_release(d_bzla, q);
    bzla_node_release(d_bzla, c);
  }

  for (auto [q, l] : d_skolemization_lemmas)
  {
    bzla_node_release(d_bzla, q);
    bzla_node_release(d_bzla, l);
  }

  for (auto [q, l] : d_ce_lemmas)
  {
    bzla_node_release(d_bzla, q);
    bzla_node_release(d_bzla, l);
  }

  for (auto [q, l] : d_ce_literals)
  {
    bzla_node_release(d_bzla, q);
    bzla_node_release(d_bzla, l);
  }

  for (auto [q, k] : d_lemma_cache)
  {
    bzla_node_release(d_bzla, q);
  }

  for (BzlaNode *a : d_assumptions)
  {
    bzla_node_release(d_bzla, a);
  }

  for (auto [sk, t] : d_synthesized_terms)
  {
    bzla_node_release(d_bzla, t);
  }

  for (auto [sort, values] : d_value_map)
  {
    for (auto n : values)
    {
      bzla_node_release(d_bzla, n);
    }
  }

  for (auto [sort, consts] : d_const_map)
  {
    for (auto n : consts)
    {
      bzla_node_release(d_bzla, n);
    }
  }

  for (auto [sort, terms] : d_term_map)
  {
    for (auto n : terms)
    {
      bzla_node_release(d_bzla, n);
    }
  }
}

void
QuantSolverState::reset()
{
  d_opt_mode =
      static_cast<BzlaOptQuantMode>(bzla_opt_get(d_bzla, BZLA_OPT_QUANT_MODE));
  d_synth_qi_data.clear();
}

/*------------------------------------------------------------------------*/

struct BzlaQuantSolver
{
  BZLA_SOLVER_STRUCT;

  std::unique_ptr<QuantSolverState> d_state;
};

/*------------------------------------------------------------------------*/

BzlaSolverResult
QuantSolverState::check_sat_ground()
{
  return d_bzla->slv->api.sat(d_bzla->slv);
}

void
QuantSolverState::generate_model_ground()
{
  d_bzla->slv->api.generate_model(d_bzla->slv, false, false);
}

void
QuantSolverState::reset_assumptions()
{
  qlog("Reset assumptions:\n");
  while (!d_assumptions.empty())
  {
    pop_assumption();
  }
}

void
QuantSolverState::pop_assumption()
{
  BzlaNode *n = d_assumptions.back();
  d_assumptions.pop_back();
  qlog("Pop assumption: %s\n", bzla_util_node2string(n));

  if (bzla_hashptr_table_get(d_bzla->orig_assumptions, n))
  {
    bzla_hashptr_table_remove(d_bzla->orig_assumptions, n, 0, 0);
    bzla_node_release(d_bzla, n);  // copy from bzla_assume_exp()
  }
  bzla_node_release(d_bzla, n);  // copy from d_assumptions

  BzlaNode *simp = d_assumptions_simp.back();
  d_assumptions_simp.pop_back();

  if (bzla_hashptr_table_get(d_bzla->assumptions, simp))
  {
    bzla_hashptr_table_remove(d_bzla->assumptions, simp, 0, 0);
    bzla_node_release(d_bzla, simp);  // copy from bzla_assume_exp()
  }
  bzla_node_release(d_bzla, simp);  // copy from d_assumptions_simp
}

bool
QuantSolverState::assume(BzlaNode *n)
{
  if (!bzla_is_assumption_exp(d_bzla, n))
  {
    // Reset flag in order to avoid resetting current assumptions when
    // calling `bzla_assume_exp()` in `assume()`.
    d_bzla->valid_assignments = 0;

    qlog("Assume: %s\n", bzla_util_node2string(n));
    bzla_assume_exp(d_bzla, n);
    d_assumptions.push_back(bzla_node_copy(d_bzla, n));
    d_assumptions_simp.push_back(
        bzla_node_copy(d_bzla, bzla_simplify_exp(d_bzla, n)));
    return true;
  }
  return false;
}

BzlaNode *
QuantSolverState::find_original_instance(BzlaNode *q)
{
  auto it = d_instantiations.find(q);
  while (it != d_instantiations.end())
  {
    assert(bzla_node_real_addr(q) != bzla_node_real_addr(it->second));
    q  = it->second;
    it = d_instantiations.find(q);
  }
  return q;
}

BzlaNode *
QuantSolverState::find_parent(BzlaNode *q)
{
  auto it = d_instantiations.find(q);
  if (it != d_instantiations.end())
  {
    return it->second;
  }
  return q;
}

void
QuantSolverState::record_instance(BzlaNode *q_inst, BzlaNode *q_orig)
{
  assert(q_inst != q_orig);

  auto it = d_instantiations.find(q_inst);
  if (it == d_instantiations.end())
  {
    d_instantiations.emplace(bzla_node_copy(d_bzla, q_inst),
                             bzla_node_copy(d_bzla, q_orig));
  }
}

void
QuantSolverState::get_active_quantifiers()
{
  uint32_t i;
  BzlaBitVector *value;
  BzlaNode *cur;
  BzlaPtrHashTableIterator it;
  BzlaNodeIterator nit;
  std::vector<BzlaNode *> visit;
  BzlaMemMgr *mm;
  NodeSet cache;

  mm = d_bzla->mm;

  /* collect top-most quantifiers reachable from assertions */
  // TODO: Cache traversed assertions
  bzla_iter_hashptr_init(&it, d_bzla->synthesized_constraints);
  bzla_iter_hashptr_queue(&it, d_bzla->assumptions);
  while (bzla_iter_hashptr_has_next(&it))
  {
    visit.push_back(static_cast<BzlaNode *>(bzla_iter_hashptr_next(&it)));
  }

  d_active_quantifiers.clear();
  d_quantifiers.clear();

  qlog("Active quantifiers:\n");
  while (!visit.empty())
  {
    cur = bzla_node_real_addr(visit.back());
    visit.pop_back();

    if (cache.find(cur) != cache.end() || !cur->quantifier_below) continue;

    cache.emplace(cur);

    if (bzla_node_is_quantifier(cur))
    {
      value = bzla_model_get_bv_assignment(d_bzla, cur);
      assert(value);
      bool phase = bzla_bv_is_true(value);
      bzla_bv_free(mm, value);
      d_active_quantifiers.push_back(cur);
      qlog("  %s (%s) (instance: %s)\n",
           bzla_util_node2string(cur),
           phase ? "true" : "false",
           bzla_util_node2string(find_original_instance(cur)));

      /* Determine polarity of each active quantifier. */
      do
      {
        bzla_iter_binder_init(&nit, cur);
        while (bzla_iter_binder_has_next(&nit))
        {
          d_quantifiers.emplace(bzla_iter_binder_next(&nit), phase);
        }
        cur = bzla_node_binder_get_body(cur);
        if (bzla_node_is_inverted(cur) && bzla_node_is_forall(cur))
        {
          phase = !phase;
        }
        cur = bzla_node_real_addr(cur);
      } while (bzla_node_is_quantifier(cur));
    }
    else
    {
      for (i = 0; i < cur->arity; ++i)
      {
        visit.push_back(cur->e[i]);
      }
    }
  }
}

bool
QuantSolverState::is_forall(BzlaNode *q)
{
  q = bzla_node_real_addr(q);

  auto it = d_quantifiers.find(q);
  if (it == d_quantifiers.end())
  {
    return false;
  }
  return it->second;
}

bool
QuantSolverState::is_exists(BzlaNode *q)
{
  q = bzla_node_real_addr(q);

  auto it = d_quantifiers.find(q);
  if (it == d_quantifiers.end())
  {
    return false;
  }
  return !it->second;
}

static BzlaNode *
substitute(Bzla *bzla,
           BzlaNode *n,
           const NodeMap<BzlaNode *> &substs,
           NodeMap<BzlaNode *> &substituted)
{
  assert(bzla);
  assert(n);

  uint32_t i;
  BzlaNode *cur, *real_cur, *subst, *result, *e[4], *c;
  std::vector<BzlaNode *> visit;
  NodeMap<BzlaNode *> cache;

  visit.push_back(n);
  while (!visit.empty())
  {
    cur      = visit.back();
    real_cur = bzla_node_real_addr(cur);
    visit.pop_back();

    auto it = cache.find(real_cur);
    if (it == cache.end())
    {
      auto itt = substs.find(real_cur);
      if (itt != substs.end())
      {
        subst = itt->second;
        cache.emplace(real_cur, bzla_node_copy(bzla, subst));

        /* Keep track of instantiated variables */
        if (bzla_node_is_param(real_cur)
            && bzla_node_param_is_forall_var(real_cur))
        {
          substituted.emplace(real_cur, bzla_node_copy(bzla, subst));
        }
        continue;
      }
      cache.emplace(real_cur, nullptr);

      visit.push_back(cur);
      for (i = 0; i < real_cur->arity; ++i)
      {
        visit.push_back(real_cur->e[i]);
      }
    }
    else if (it->second == nullptr)
    {
      for (i = 0; i < real_cur->arity; ++i)
      {
        c = bzla_node_real_addr(real_cur->e[i]);
        assert(cache.find(c) != cache.end());
        e[i] = bzla_node_cond_invert(real_cur->e[i], cache.at(c));
      }

      if (real_cur->arity == 0)
      {
        if (bzla_node_is_param(real_cur))
        {
          result = bzla_node_create_param(bzla,
                                          bzla_node_get_sort_id(real_cur),
                                          bzla_node_get_symbol(bzla, real_cur));
        }
        else
        {
          result = bzla_node_copy(bzla, real_cur);
        }
      }
      else if (bzla_node_is_bv_slice(real_cur))
      {
        result = bzla_exp_bv_slice(bzla,
                                   e[0],
                                   bzla_node_bv_slice_get_upper(real_cur),
                                   bzla_node_bv_slice_get_lower(real_cur));
      }
      else if (bzla_node_is_fp_to_sbv(real_cur))
      {
        result = bzla_exp_fp_to_sbv(
            bzla, e[0], e[1], bzla_node_get_sort_id(real_cur));
      }
      else if (bzla_node_is_fp_to_ubv(real_cur))
      {
        result = bzla_exp_fp_to_ubv(
            bzla, e[0], e[1], bzla_node_get_sort_id(real_cur));
      }
      else if (bzla_node_is_fp_to_fp_from_bv(real_cur))
      {
        result = bzla_exp_fp_to_fp_from_bv(
            bzla, e[0], bzla_node_get_sort_id(real_cur));
      }
      else if (bzla_node_is_fp_to_fp_from_fp(real_cur))
      {
        result = bzla_exp_fp_to_fp_from_fp(
            bzla, e[0], e[1], bzla_node_get_sort_id(real_cur));
      }
      else if (bzla_node_is_fp_to_fp_from_sbv(real_cur))
      {
        result = bzla_exp_fp_to_fp_from_sbv(
            bzla, e[0], e[1], bzla_node_get_sort_id(real_cur));
      }
      else if (bzla_node_is_fp_to_fp_from_ubv(real_cur))
      {
        result = bzla_exp_fp_to_fp_from_ubv(
            bzla, e[0], e[1], bzla_node_get_sort_id(real_cur));
      }
      else
      {
        /* if the param of a quantifier gets subtituted by a non-param,
         * we do not create a quantifier, but return the body instead */
        if (bzla_node_is_quantifier(real_cur) && !bzla_node_is_param(e[0]))
        {
          result = bzla_node_copy(bzla, e[1]);
        }
        else
        {
          result = bzla_exp_create(bzla, real_cur->kind, e, real_cur->arity);

          if (bzla_node_is_quantifier(real_cur)
              && bzla_node_is_quantifier(result))
          {
            substituted.emplace(real_cur, bzla_node_copy(bzla, result));
          }
        }
      }
      assert(bzla_node_get_sort_id(real_cur) == bzla_node_get_sort_id(result));

      if (bzla_node_is_param(real_cur)
          && bzla_node_param_is_forall_var(real_cur))
      {
        substituted.emplace(real_cur, bzla_node_copy(bzla, result));
      }

      it->second = result;
    }
  }
  assert(cache.find(bzla_node_real_addr(n)) != cache.end());

  result = bzla_node_cond_invert(
      n, bzla_node_copy(bzla, cache.at(bzla_node_real_addr(n))));

  for (auto &p : cache)
  {
    bzla_node_release(bzla, p.second);
  }
  return result;
}

void
QuantSolverState::add_instance(BzlaNode *q_orig,
                               BzlaNode *q_inst,
                               const NodeMap<BzlaNode *> &substs)
{
  if (q_orig == q_inst)
  {
    return;
  }

  record_instance(q_inst, q_orig);

  // Instance already added.
  if (d_deps.find(q_inst) != d_deps.end())
  {
    return;
  }

  qlog("Add new instance: %s (from %s)\n",
       bzla_util_node2string(q_inst),
       bzla_util_node2string(q_orig));

  // Compute dependencies for `q_inst`.
  auto it = d_deps.find(q_orig);
  if (it != d_deps.end())
  {
    auto &q_orig_deps = it->second;
    std::vector<BzlaNode *> q_inst_deps;
    for (auto cur : q_orig_deps)
    {
      auto it = substs.find(cur);
      if (it != substs.end())
      {
        q_inst_deps.push_back(bzla_node_copy(d_bzla, it->second));
        qlog("  dep: %s -> %s\n",
             bzla_util_node2string(cur),
             bzla_util_node2string(it->second));
      }
      else
      {
        q_inst_deps.push_back(bzla_node_copy(d_bzla, cur));
        qlog("  dep: %s\n", bzla_util_node2string(cur));
      }
    }
    d_deps.emplace(bzla_node_copy(d_bzla, q_inst), q_inst_deps);
  }
}

BzlaNode *
QuantSolverState::instantiate(BzlaNode *q, const NodeMap<BzlaNode *> &substs)
{
  assert(bzla_node_is_quantifier(q));

  NodeMap<BzlaNode *> substituted;
  BzlaNode *result;

  result = substitute(d_bzla, q, substs, substituted);

  for (auto [q_orig, q_inst] : substituted)
  {
    if (bzla_node_is_quantifier(q_orig))
    {
      add_instance(q_orig, q_inst, substituted);
    }
    bzla_node_release(d_bzla, q_inst);
  }

  return result;
}

BzlaNode *
QuantSolverState::get_inst_constant(BzlaNode *q)
{
  BzlaNode *sk;
  BzlaSortId sort;

  auto it = d_instantiation_constants.find(q);
  if (it != d_instantiation_constants.end())
  {
    return it->second;
  }

  std::stringstream ss;
  char *sym = bzla_node_get_symbol(d_bzla, q->e[0]);
  if (sym)
  {
    ss << "ic(" << sym << ")";
  }
  sort = bzla_node_get_sort_id(q->e[0]);
  sk   = bzla_node_create_var(d_bzla, sort, ss.str().c_str());
  qlog("Inst constant %s for %s\n",
       bzla_util_node2string(sk),
       bzla_util_node2string(q));

  d_instantiation_constants.emplace(bzla_node_copy(d_bzla, q), sk);

  return sk;
}

BzlaNode *
QuantSolverState::get_skolem(BzlaNode *q)
{
  BzlaNode *result = nullptr;

  auto key   = std::make_pair(q, nullptr);
  auto it_sk = d_skolems.find(key);
  if (it_sk != d_skolems.end())
  {
    qlog("Use skolem (%s): %s\n",
         bzla_util_node2string(it_sk->second),
         bzla_util_node2string(q));
    return it_sk->second;
  }

  auto q_parent = find_parent(q);
  auto it       = d_deps.find(q);
  if (d_opt_skolem_uf && it != d_deps.end())
  {
    std::vector<BzlaSortId> sorts;
    std::vector<BzlaNode *> args, vars;
    auto &q_deps        = it->second;
    auto &q_deps_parent = d_deps.at(q_parent);
    assert(q_deps.size() == q_deps_parent.size());

    // Collect sorts of universal variable dependencies.
    for (size_t i = 0; i < q_deps_parent.size(); ++i)
    {
      auto cur = q_deps_parent[i];
      if (bzla_node_is_param(cur) && is_forall(bzla_node_param_get_binder(cur)))
      {
        qlog("  %s: %s\n",
             bzla_util_node2string(cur),
             bzla_util_node2string(q_deps[i]));
        sorts.push_back(bzla_node_get_sort_id(q_deps[i]));
        args.push_back(q_deps[i]);
        vars.push_back(cur);
      }
    }
    // TODO: hashing by vars may not be necessary anymore since we now use
    // q_parent

    // Need Skolem function.
    if (!sorts.empty())
    {
      BzlaNode *sk = nullptr;
      BzlaNode *arg_vars =
          bzla_node_create_args(d_bzla, vars.data(), vars.size());
      auto key = std::make_pair(q_parent, arg_vars);

      auto it = d_skolems.find(key);
      // Use Skolem of original instance.
      if (it != d_skolems.end())
      {
        sk = it->second;
      }
      // No Skolem created yet for `q_parent`.
      else
      {
        BzlaSortId domain = bzla_sort_tuple(d_bzla, sorts.data(), sorts.size());
        BzlaSortId codomain = bzla_node_get_sort_id(q->e[0]);
        BzlaSortId sort     = bzla_sort_fun(d_bzla, domain, codomain);
        bzla_sort_release(d_bzla, domain);

        std::stringstream ss;
        const char *sym = bzla_node_get_symbol(d_bzla, q->e[0]);
        if (sym)
        {
          ss << "sk(" << sym << ")";
        }
        sk = bzla_exp_uf(d_bzla, sort, ss.str().c_str());
        bzla_sort_release(d_bzla, sort);

        // Cache Skolem for `q_parent`.
        assert(d_skolems.find(key) == d_skolems.end());
        d_skolems.emplace(key, sk);
        bzla_node_copy(d_bzla, key.first);
        bzla_node_copy(d_bzla, key.second);

        /* We currently only support synthesis for bit-vectors sorts, but not
         * FP sorts. Therefore, we have to check if the sorts for this function
         * are bit-vector only. */
        bool can_synth = bzla_sort_is_bv(d_bzla, codomain);
        if (can_synth)
        {
          for (BzlaSortId s : sorts)
          {
            if (!bzla_sort_is_bv(d_bzla, s))
            {
              can_synth = false;
              break;
            }
          }
        }

        if (can_synth)
        {
          d_use_synth.insert(sk);
        }
      }

      qlog("%s skolem UF (%s, arity: %zu): %s (%s)\n",
           it == d_skolems.end() ? "New" : "Use",
           bzla_util_node2string(sk),
           sorts.size(),
           bzla_util_node2string(q),
           bzla_util_node2string(q_parent));

      assert(sk);
      bzla_node_release(d_bzla, arg_vars);
      assert(args.size() == bzla_node_fun_get_arity(d_bzla, sk));
      result = bzla_exp_apply_n(d_bzla, sk, args.data(), args.size());

      // Cache Skolem for `q`.
      key = std::make_pair(bzla_node_copy(d_bzla, q), nullptr);
      assert(d_skolems.find(key) == d_skolems.end());
      d_skolems.emplace(key, result);
    }
  }

  // No dependencies, just create a skolem constant.
  if (!result)
  {
    std::stringstream ss;
    const char *sym = bzla_node_get_symbol(d_bzla, q->e[0]);
    if (sym)
    {
      ss << "sk(" << sym << ")";
    }
    result = bzla_node_create_var(
        d_bzla, bzla_node_get_sort_id(q->e[0]), ss.str().c_str());

    key = std::make_pair(bzla_node_copy(d_bzla, q), nullptr);
    assert(d_skolems.find(key) == d_skolems.end());
    d_skolems.emplace(key, result);

    qlog("New skolem (%s): %s (%s)\n",
         bzla_util_node2string(result),
         bzla_util_node2string(q),
         bzla_util_node2string(q_parent));
  }

  return result;
}

BzlaNode *
QuantSolverState::get_ce_literal(BzlaNode *q)
{
  BzlaNode *lit;
  BzlaSortId sort;

  auto it = d_ce_literals.find(q);
  if (it != d_ce_literals.end())
  {
    return it->second;
  }

  sort = bzla_sort_bool(d_bzla);

  std::stringstream ss;
  ss << "celit(" << bzla_node_get_id(q) << ")";
  lit = bzla_node_create_var(d_bzla, sort, ss.str().c_str());
  d_ce_literals.emplace(bzla_node_copy(d_bzla, q), lit);
  bzla_sort_release(d_bzla, sort);

  return lit;
}

BzlaNode *
QuantSolverState::skolemize(BzlaNode *q)
{
  assert(bzla_node_is_regular(q));
  assert(bzla_node_is_forall(q));
  assert(!q->parameterized);

  BzlaNode *cur, *sk, *inst;
  BzlaNodeIterator it;
  NodeMap<BzlaNode *> map;

  qlog("Skolemize %s (%s, %s)\n",
       bzla_util_node2string(q),
       bzla_util_node2string(find_original_instance(q)),
       bzla_util_node2string(find_parent(q)));
  bzla_iter_binder_init(&it, q);
  while (bzla_iter_binder_has_next(&it))
  {
    cur = bzla_iter_binder_next(&it);
    sk  = get_skolem(cur);
    map.emplace(cur->e[0], sk);
    qlog("  %s -> %s\n",
         bzla_util_node2string(cur->e[0]),
         bzla_util_node2string(sk));
  }

  inst = instantiate(q, map);
  assert(!bzla_node_real_addr(inst)->parameterized);

  return inst;
}

BzlaNode *
QuantSolverState::get_skolemization_lemma(BzlaNode *q)
{
  assert(bzla_node_is_regular(q));
  assert(!q->parameterized);

  BzlaNode *inst, *lemma;

  auto it = d_skolemization_lemmas.find(q);
  if (it != d_skolemization_lemmas.end())
  {
    return it->second;
  }
  qlog("Add skolemization lemma: %s\n", bzla_util_node2string(q));

  inst  = skolemize(q);
  lemma = bzla_exp_implies(d_bzla, bzla_node_invert(q), bzla_node_invert(inst));
  bzla_node_release(d_bzla, inst);
  d_skolemization_lemmas.emplace(bzla_node_copy(d_bzla, q), lemma);
  return lemma;
}

bool
QuantSolverState::added_skolemization_lemma(BzlaNode *q)
{
  return d_skolemization_lemmas.find(q) != d_skolemization_lemmas.end();
}

BzlaNode *
QuantSolverState::get_ce_lemma(BzlaNode *q)
{
  assert(bzla_node_is_regular(q));
  assert(!q->parameterized);

  BzlaNode *cur, *ic, *inst, *lem;
  BzlaNodeIterator it;
  NodeMap<BzlaNode *> map;

  auto itt = d_ce_lemmas.find(q);
  if (itt != d_ce_lemmas.end())
  {
    return itt->second;
  }

  qlog("Add CE lemma: %s (%s)\n---\n",
       bzla_util_node2string(q),
       bzla_util_node2string(find_original_instance(q)));

  /* Get instantiations constants for variables in q. */
  bzla_iter_binder_init(&it, q);
  while (bzla_iter_binder_has_next(&it))
  {
    cur = bzla_iter_binder_next(&it);
    ic  = get_inst_constant(cur);
    map.emplace(cur->e[0], ic);
  }

  inst = instantiate(q, map);
  assert(!bzla_node_real_addr(inst)->parameterized);

  if (d_opt_eager_skolem && bzla_node_is_inverted(inst)
      && bzla_node_is_forall(inst))
  {
    BzlaNode *inst_skolemized = skolemize(bzla_node_real_addr(inst));
    bzla_node_release(d_bzla, inst);
    inst = bzla_node_invert(inst_skolemized);
  }

  lem = bzla_exp_implies(d_bzla, get_ce_literal(q), bzla_node_invert(inst));
  bzla_node_release(d_bzla, inst);
  d_ce_lemmas.emplace(bzla_node_copy(d_bzla, q), lem);

  qlog("---\n");

  return lem;
}

bool
QuantSolverState::added_ce_lemma(BzlaNode *q)
{
  return d_ce_lemmas.find(q) != d_ce_lemmas.end();
}

BzlaNode *
get_value(Bzla *bzla, BzlaNode *n)
{
  return bzla_model_get_value(bzla, n);
}

bool
QuantSolverState::add_lemma(BzlaNode *lem, LemmaKind k)
{
  auto it = d_lemma_cache.find(lem);
  if (it != d_lemma_cache.end())
  {
    qlog(
        "Duplicate lemma (%s): %s\n", to_string(k), bzla_util_node2string(lem));
    return false;
  }
  qlog("Add lemma (%s): %s\n", to_string(k), bzla_util_node2string(lem));
  d_lemma_cache.emplace(bzla_node_copy(d_bzla, lem), k);
  d_lemmas.push_back(lem);
  d_added_lemma = true;
  return true;
}

void
QuantSolverState::assert_lemmas()
{
  qlog("Assert lemmas\n");
  // Reset flag in order to avoid resetting current assumptions when
  // calling `bzla_assert_exp()` in `assert_lemmas()`.
  d_bzla->valid_assignments = 0;
  for (BzlaNode *lem : d_lemmas)
  {
    qlog("  Lemma: %s\n", bzla_util_node2string(lem));
    bzla_assert_exp(d_bzla, lem);
  }
  d_lemmas.clear();
}

void
QuantSolverState::add_value_instantiation_lemma(BzlaNode *q)
{
  assert(bzla_node_is_regular(q));
  assert(!q->parameterized);

  BzlaNode *cur, *ic, *inst, *lem, *value;
  BzlaNodeIterator it;
  NodeMap<BzlaNode *> map;

  qlog("<<< Add value instantiation: %s\n", bzla_util_node2string(q));
  /* Collect model values for instantiation constants of q. */
  bzla_iter_binder_init(&it, q);
  while (bzla_iter_binder_has_next(&it))
  {
    cur   = bzla_iter_binder_next(&it);
    ic    = get_inst_constant(cur);
    value = get_value(d_bzla, ic);
    map.emplace(cur->e[0], value);
    qlog("  %s -> %s\n",
         bzla_util_node2string(cur->e[0]),
         bzla_util_node2string(value));
  }

  inst = instantiate(q, map);
  assert(!bzla_node_real_addr(inst)->parameterized);

  if (d_opt_eager_skolem && bzla_node_is_inverted(inst)
      && bzla_node_is_forall(inst))
  {
    BzlaNode *inst_skolemized = skolemize(bzla_node_real_addr(inst));
    bzla_node_release(d_bzla, inst);
    inst = bzla_node_invert(inst_skolemized);
  }

  for (auto &p : map)
  {
    bzla_node_release(d_bzla, p.second);
  }

  lem = bzla_exp_implies(d_bzla, q, inst);
  bzla_node_release(d_bzla, inst);
  add_lemma(lem, LemmaKind::VALUE_INST);
  bzla_node_release(d_bzla, lem);
  ++d_statistics.num_value_inst_lemmas;
  qlog("<<<\n");
}

bool
QuantSolverState::added_new_lemmas() const
{
  return d_added_lemma;
}

void
QuantSolverState::set_inactive(BzlaNode *q)
{
  assert(d_inactive_quantifiers.find(q) == d_inactive_quantifiers.end());
  d_inactive_quantifiers.emplace(bzla_node_copy(d_bzla, q));
  qlog("Set inactive: %s\n", bzla_util_node2string(q));
}

bool
QuantSolverState::is_inactive(BzlaNode *q)
{
  return d_inactive_quantifiers.find(q) != d_inactive_quantifiers.end();
}

void
QuantSolverState::get_fun_model(BzlaNode *sk_fun,
                                std::vector<BzlaBitVectorTuple *> &values_in,
                                std::vector<BzlaBitVector *> &values_out)
{
  size_t i;
  const BzlaBitVector *bv;
  BzlaArgsIterator it;
  BzlaBitVectorTuple *bvtup;
  BzlaNode *arg;

  /* Only collect model values relevant to synthesizing a term for sk_fun,
   * i.e., from Skolems introduced via value instantiation (from
   * counterexamples). */
  for (auto [q, sk] : d_skolems)
  {
    if (bzla_node_is_apply(sk) && sk->e[0] == sk_fun)
    {
      i = 0;

      bool relevant = true;
      bzla_iter_args_init(&it, sk->e[1]);
      while (bzla_iter_args_has_next(&it))
      {
        arg = bzla_iter_args_next(&it);
        if (!bzla_node_is_bv_const(arg))
        {
          relevant = false;
        }
      }
      if (!relevant) continue;

      bvtup = bzla_bv_new_tuple(d_bzla->mm,
                                bzla_node_fun_get_arity(d_bzla, sk_fun));
      bzla_iter_args_init(&it, sk->e[1]);
      while (bzla_iter_args_has_next(&it))
      {
        arg = bzla_iter_args_next(&it);
        bv  = bzla_model_get_bv(d_bzla, arg);
        bzla_bv_add_to_tuple(d_bzla->mm, bvtup, bv, i++);
      }
      values_in.push_back(bvtup);

      bv = bzla_model_get_bv(d_bzla, sk);
      values_out.push_back(bzla_bv_copy(d_bzla->mm, bv));
    }
  }
}

void
QuantSolverState::synthesize_terms()
{
  std::vector<BzlaNode *> quantifiers;
  BzlaNode *prev_f;

  generate_model_ground();

  // TODO: check if we only need to do this for active quantifiers
  for (auto [p, sk] : d_skolems)
  {
    BzlaNode *q_orig = find_original_instance(p.first);

    /* We only need to synthesize for Skolem UFs / constants, but not for
     * applications on UFs. */
    if (p.first != q_orig) continue;

    /**
     * Synthesize Skolem function.
     *
     * Uses enumerative syntax-guided synthesis to synthesize a Skolem function
     * based on concrete input/output pairs. The input/output pairs are
     * constructed from the current model of the Skolem UF `sk`.
     */
    if (d_opt_synth_sk && bzla_node_is_fun(sk)
        && d_use_synth.find(sk) != d_use_synth.end())
    {
      prev_f       = nullptr;
      auto it_prev = d_synthesized_terms.find(sk);
      if (it_prev != d_synthesized_terms.end())
      {
        prev_f = it_prev->second;
      }

      qlog("Synthesize term for %s\n", bzla_util_node2string(sk));
      std::vector<BzlaBitVectorTuple *> values_in;
      std::vector<BzlaBitVector *> values_out;
      std::vector<BzlaNode *> params, inputs;

      get_fun_model(sk, values_in, values_out);

      // const BzlaPtrHashTable *m = bzla_model_get_fun(d_bzla, sk);
      if (values_in.empty())
      {
        qlog("  no model, skip\n");
        goto MODEL_VALUE;
      }

      if (prev_f)
      {
        // TODO: add params of prev_f to value_in_map so that we can pass
        // prev_f to bzla_synthesize_term.
      }

      BzlaSortId domain =
          bzla_sort_fun_get_domain(d_bzla, bzla_node_get_sort_id(sk));
      BzlaNode *param;
      BzlaSortId sort;
      BzlaTupleSortIterator sit;
      bzla_iter_tuple_sort_init(&sit, d_bzla, domain);
      while (bzla_iter_tuple_sort_has_next(&sit))
      {
        sort  = bzla_iter_tuple_sort_next(&sit);
        param = bzla_node_create_param(d_bzla, sort, 0);
        params.push_back(param);
        inputs.push_back(param);
      }

      // inputs ... vector of params/consts
      // input/output pairs
      //   - input ... vector of values
      //   - output ... value
      // input_map ... maps input ids to index in input vector

      // TODO:
      // - collect values from formula
      //   -> add more special values?
      //
      // - collect additional constants
      //   -> always add (Skolem) constants (global scope)
      //
      //
      BzlaSortId codomain =
          bzla_sort_fun_get_codomain(d_bzla, bzla_node_get_sort_id(sk));

      auto it           = d_value_map.find(codomain);
      std::vector<BzlaNode *> values =
          it == d_value_map.end() ? std::vector<BzlaNode *>() : it->second;

      qlog(">>> Synthesize term for %s\n", bzla_util_node2string(sk));
      qlog_print_synth_table(d_bzla, inputs, values_in, values_out, values);
      BzlaNode *t =
          synth::bzla_synthesize_term(d_bzla,
                                      inputs,
                                      values_in,
                                      values_out,
                                      values,    // special constants
                                      10000,     // max checks
                                      5,         // max levels
                                      nullptr);  // BzlaNode *prev_synth)
      qlog(">>> Result: %s\n", bzla_util_node2string(t));

      for (BzlaBitVectorTuple *bvtup : values_in)
      {
        bzla_bv_free_tuple(d_bzla->mm, bvtup);
      }
      for (BzlaBitVector *bv : values_out)
      {
        bzla_bv_free(d_bzla->mm, bv);
      }

      // Create new candidate function with synthesized term `t`.
      if (t)
      {
        BzlaNode *f = bzla_exp_fun(d_bzla, params.data(), params.size(), t);
        bzla_node_release(d_bzla, t);

#ifdef QLOG
        // bzla_dumpsmt_dump_node(d_bzla, stdout, f, 0);
#endif

        store_synthesized_term(sk, f);
        bzla_node_release(d_bzla, f);
      }
      // Was not able to synthesize a candidate term for current input/output
      // pairs. Delete previously synthesized function since it does not have
      // the expected input/output behavior for Skolem UF `sk`.
      else if (prev_f)
      {
        store_synthesized_term(sk, nullptr);
      }

      for (BzlaNode *p : params)
      {
        bzla_node_release(d_bzla, p);
      }
    }
    /* Use current model value for Skolem constants. */
    else
    {
    MODEL_VALUE:
      qlog("Use model value for %s\n", bzla_util_node2string(sk));
      BzlaNode *value = get_value(d_bzla, sk);
      store_synthesized_term(sk, value);
      bzla_node_release(d_bzla, value);
    }
  }
}

void
QuantSolverState::store_synthesized_term(BzlaNode *sk, BzlaNode *term)
{
  auto it = d_synthesized_terms.find(sk);

  if (it == d_synthesized_terms.end())
  {
    d_synthesized_terms.emplace(sk, bzla_node_copy(d_bzla, term));
  }
  else
  {
    /* Delete synthesized term for sk. */
    if (term == nullptr)
    {
      bzla_node_release(d_bzla, it->second);
      d_synthesized_terms.erase(it);
      return;
    }
    /* Term is the same, do nothing. */
    if (it->second == term)
    {
      return;
    }
    /* Otherwise, delete old term and store new one. */
    bzla_node_release(d_bzla, it->second);
    it->second = bzla_node_copy(d_bzla, term);
  }
}

void
QuantSolverState::synthesize_qi(BzlaNode *q)
{
  // Synthesize candidate term for each quantifier.
  BzlaNodeIterator nit;
  BzlaNode *cur_q, *ic;
  NodeMap<BzlaNode *> map;

  // Construct input/output pair where
  // ... inputs are constants, values and dependant variables
  // ... output is the current model value of the instantiation constant
  bzla_iter_binder_init(&nit, q);
  while (bzla_iter_binder_has_next(&nit))
  {
    cur_q = bzla_iter_binder_next(&nit);
    ic    = get_inst_constant(cur_q);
    qlog("Synthesize QI: %s\n", bzla_util_node2string(cur_q));

    BzlaNode *t = nullptr;
    // For now, we can only synthesize terms for bit-vector sorts
    if (bzla_sort_is_bv(d_bzla, bzla_node_get_sort_id(ic)))
    {
      auto [it_sd, inserted] = d_synth_qi_data.emplace(cur_q, d_bzla->mm);
      auto &synth_data       = it_sd->second;

      std::vector<BzlaNode *> inputs;
      std::vector<const BzlaBitVector *> input_values;

      synth_data.d_values_out.push_back(
          bzla_bv_copy(d_bzla->mm, bzla_model_get_bv(d_bzla, ic)));

      // TODO: remove duplicate inputs

      // Add constants with same sort as inputs.
      BzlaSortId sort_id = bzla_node_get_sort_id(ic);
      auto it            = d_const_map.find(sort_id);
      if (it != d_const_map.end())
      {
        auto &consts = it->second;
        for (BzlaNode *c : consts)
        {
          assert(bzla_node_is_regular(c));
          assert(!bzla_node_is_proxy(c));
          assert(bzla_node_is_bv_var(c));
          inputs.push_back(c);
          input_values.push_back(bzla_model_get_bv(d_bzla, c));
          assert(input_values.back());
        }
      }

      // Add dependencies as inputs
      // Note: For now we use the dependencies of the top-most quantifier for
      // nested quantifiers.
      // TODO: Reuse already synthesized terms from outer quantifiers for nested
      // quantifiers.
      auto itt = d_deps.find(q);
      if (itt != d_deps.end())
      {
        for (BzlaNode *dep : itt->second)
        {
          // Note: We currently only support bit-vector types for synthesis.
          if (bzla_node_is_bv(d_bzla, dep))
          {
            inputs.push_back(dep);
            input_values.push_back(bzla_model_get_bv(d_bzla, dep));
            assert(input_values.back());
          }
        }
      }

      BzlaBitVectorTuple *bvt =
          bzla_bv_new_tuple(d_bzla->mm, input_values.size());
      for (size_t i = 0; i < input_values.size(); ++i)
      {
        bzla_bv_add_to_tuple(d_bzla->mm, bvt, input_values[i], i);
      }
      synth_data.d_values_in.push_back(bvt);

      auto itv = d_value_map.find(sort_id);
      std::vector<BzlaNode *> values =
          itv == d_value_map.end() ? std::vector<BzlaNode *>() : itv->second;

      if (!inputs.empty())
      {
        qlog(">>> Synthesize QI for %s\n", bzla_util_node2string(cur_q));
        qlog_print_synth_table(d_bzla,
                               inputs,
                               synth_data.d_values_in,
                               synth_data.d_values_out,
                               values);
        t = synth::bzla_synthesize_term(d_bzla,
                                        inputs,
                                        synth_data.d_values_in,
                                        synth_data.d_values_out,
                                        values,
                                        10000,     // max checks
                                        5,         // max levels
                                        nullptr);  // BzlaNode *prev_synth)
        qlog(">>> Result: %s\n", bzla_util_node2string(t));
      }
      else
      {
        qlog("No inputs\n");
      }
    }

    if (t)
    {
      map[cur_q->e[0]] = t;
    }
    else
    {
      map[cur_q->e[0]] = get_value(d_bzla, ic);
    }
  }

  // TODO: This is not necessary if no t synthesized since we already added a
  // value instantiation.
  BzlaNode *inst = instantiate(q, map);

  assert(!bzla_node_real_addr(inst)->parameterized);

  if (d_opt_eager_skolem && bzla_node_is_inverted(inst)
      && bzla_node_is_forall(inst))
  {
    BzlaNode *inst_skolemized = skolemize(bzla_node_real_addr(inst));
    bzla_node_release(d_bzla, inst);
    inst = bzla_node_invert(inst_skolemized);
  }

  for (auto &p : map)
  {
    bzla_node_release(d_bzla, p.second);
  }

  BzlaNode *lem = bzla_exp_implies(d_bzla, q, inst);
  bzla_node_release(d_bzla, inst);
  if (add_lemma(lem, LemmaKind::SYNTH_INST))
  {
    ++d_statistics.num_synth_qi_lemmas;
  }
  bzla_node_release(d_bzla, lem);
}

void
QuantSolverState::mbqi(BzlaNode *q)
{
  BzlaNodeIterator nit;
  BzlaNode *cur_q, *ic;
  NodeMap<BzlaNode *> map;

  bool found_term = false;
  bzla_iter_binder_init(&nit, q);
  while (bzla_iter_binder_has_next(&nit))
  {
    cur_q       = bzla_iter_binder_next(&nit);
    ic          = get_inst_constant(cur_q);
    auto ic_val = bzla_model_get_bv(d_bzla, ic);

    BzlaNode *t = nullptr;

    // Find terms with same value as ic.
    BzlaSortId sort_id = bzla_node_get_sort_id(ic);
    auto it            = d_term_map.find(sort_id);
    if (it != d_term_map.end())
    {
      auto &consts = it->second;
      for (BzlaNode *c : consts)
      {
        assert(bzla_node_is_regular(c));
        auto val = bzla_model_get_bv(d_bzla, c);
        if (bzla_bv_compare(val, ic_val) == 0)
        {
          t = c;
          break;
        }
      }
    }

    if (t)
    {
      map[cur_q->e[0]] = bzla_node_copy(d_bzla, t);
      found_term       = true;
      qlog("mbqi inst: %s -> %s\n",
           bzla_util_node2string(cur_q->e[0]),
           bzla_util_node2string(t));
    }
    else
    {
      map[cur_q->e[0]] = get_value(d_bzla, ic);
      qlog("mbqi inst: %s -> %s\n",
           bzla_util_node2string(cur_q->e[0]),
           bzla_util_node2string(map[cur_q->e[0]]));
    }
  }

  if (found_term)
  {
    BzlaNode *inst = instantiate(q, map);

    assert(!bzla_node_real_addr(inst)->parameterized);

    if (d_opt_eager_skolem && bzla_node_is_inverted(inst)
        && bzla_node_is_forall(inst))
    {
      BzlaNode *inst_skolemized = skolemize(bzla_node_real_addr(inst));
      bzla_node_release(d_bzla, inst);
      inst = bzla_node_invert(inst_skolemized);
    }

    BzlaNode *lem = bzla_exp_implies(d_bzla, q, inst);
    bzla_node_release(d_bzla, inst);
    if (add_lemma(lem, LemmaKind::MBQI_INST))
    {
      ++d_statistics.num_mbqi_lemmas;
    }
    bzla_node_release(d_bzla, lem);
  }

  for (auto &p : map)
  {
    bzla_node_release(d_bzla, p.second);
  }
}

bool
QuantSolverState::check_active_quantifiers()
{
  bool done = false;
  double start;
  BzlaNode *lit;
  BzlaSolverResult res;
  std::vector<BzlaNode *> to_check, to_synth, model_assumptions, lemmas;

  assert(d_lemmas.empty());
  d_added_lemma = false;
  start         = bzla_util_time_stamp();
  get_active_quantifiers();
  for (BzlaNode *q : d_active_quantifiers)
  {
    if (is_forall(q))
    {
      if (!is_inactive(q))
      {
        if (!added_ce_lemma(q)
            && add_lemma(get_ce_lemma(q), LemmaKind::COUNTEREXAMPLE))
        {
          ++d_statistics.num_ce_lemmas;
        }
        to_check.push_back(q);
      }
    }
    else
    {
      assert(is_exists(q));
      if (!added_skolemization_lemma(q)
          && add_lemma(get_skolemization_lemma(q), LemmaKind::SKOLEMIZATION))
      {
        ++d_statistics.num_skolemization_lemmas;
      }
      // to_synth.push_back(q);
    }
  }
  d_statistics.time_get_active += bzla_util_time_stamp() - start;

  if (added_new_lemmas())
  {
    assert_lemmas();
    return false;
  }

  /* If the previous ground check was satisfiable with all counterexample
   * literals assumed, we can just use the current model to instantiate all
   * active quantifiers. */
  if (d_opt_mode == BZLA_QUANT_MODE_EAGER_REUSE && d_last_ground_check_ok)
  {
    generate_model_ground();
    for (BzlaNode *q : to_check)
    {
      ++d_statistics.num_counterexample_checks;
      add_value_instantiation_lemma(q);
      if (d_opt_synth_qi)
      {
        synthesize_qi(q);
      }
      if (d_opt_mbqi)
      {
        mbqi(q);
      }
    }
    assert_lemmas();
    return false;
  }

  /* Synthesize functions for Skolem UFs and assume candidate model.  For
   * skolem constants the current model value is used. */
  start = bzla_util_time_stamp();
  synthesize_terms();
  d_statistics.time_synthesize_terms += bzla_util_time_stamp() - start;

  for (auto [sk, model_candidate] : d_synthesized_terms)
  {
    BzlaNode *eq = bzla_exp_eq(d_bzla, sk, model_candidate);
    model_assumptions.push_back(eq);
  }

  for (auto c : d_constants)
  {
    BzlaNode *val = get_value(d_bzla, c);
    BzlaNode *eq  = bzla_exp_eq(d_bzla, c, val);
    bzla_node_release(d_bzla, val);
    model_assumptions.push_back(eq);
  }

#ifdef QLOG
  // printf("\n");
  // bzla_dumpsmt_dump(d_bzla, stdout);
#endif

  // Assume current model.
  qlog("Assume model values.\n---\n");
  for (auto a : model_assumptions)
  {
    assume(a);
    bzla_node_release(d_bzla, a);
  }
  qlog("---\n");

  // Check for counterexamples under current candidate model.
  start               = bzla_util_time_stamp();
  size_t num_inactive = 0;
  for (BzlaNode *q : to_check)
  {
    if (d_bzla->inconsistent)
    {
      break;
    }

    ++d_statistics.num_counterexample_checks;
    qlog("***\n");

    lit = get_ce_literal(q);
    bool assumed = assume(lit);

    qlog("Check for counterexamples (%s): ", bzla_util_node2string(q));
    res = check_sat_ground();
    // Counterexample found, add new instantiation.
    if (res == BZLA_RESULT_SAT)
    {
      qlog("sat\n");
      generate_model_ground();
      add_value_instantiation_lemma(q);
      if (d_opt_synth_qi)
      {
        synthesize_qi(q);
      }
      if (d_opt_mbqi)
      {
        mbqi(q);
      }
      assert_lemmas();
    }
    // No counterexamples found anymore, set quantifier to inactive.
    else
    {
      qlog("unsat\n");
      if (bzla_failed_exp(d_bzla, lit))
      {
        ++num_inactive;
        //set_inactive(q);
      }
    }

    if (assumed)
    {
      pop_assumption();
    }
    qlog("***\n");
  }
  done = num_inactive == to_check.size();

  reset_assumptions();

  d_statistics.time_check_counterexamples += bzla_util_time_stamp() - start;

  return done;
}

void
QuantSolverState::compute_variable_dependencies_aux(
    BzlaNode *q, std::vector<BzlaNode *> &free_vars)
{
  BzlaNode *cur;
  std::vector<BzlaNode *> visit;
  NodeSet cache;
  BzlaNodeIterator nit;

  bzla_iter_binder_init(&nit, q);
  while (bzla_iter_binder_has_next(&nit))
  {
    auto cur = bzla_iter_binder_next(&nit);
    cache.emplace(cur->e[0]);
  }

  visit.push_back(q);
  while (!visit.empty())
  {
    cur = bzla_node_real_addr(visit.back());
    visit.pop_back();

    if (!cur->parameterized || cache.find(cur) != cache.end())
    {
      continue;
    }
    cache.emplace(cur);

    if (bzla_node_is_quantifier(cur))
    {
      cache.emplace(cur->e[0]);
    }
    else if (bzla_node_is_param(cur) && bzla_node_param_is_forall_var(cur))
    {
      free_vars.push_back(bzla_node_copy(d_bzla, cur));
      qlog("  %s\n", bzla_util_node2string(cur));
    }

    for (uint32_t i = 0; i < cur->arity; ++i)
    {
      visit.push_back(cur->e[i]);
    }
  }
}

void
QuantSolverState::compute_variable_dependencies(
    const std::vector<BzlaNode *> quantifiers)
{
  BzlaNodeIterator nit;
  std::unordered_set<BzlaNode *> cache;
  for (const auto q : quantifiers)
  {
    if (!q->parameterized)
    {
      // Skip all quantifiers in same block.
      bzla_iter_binder_init(&nit, q);
      while (bzla_iter_binder_has_next(&nit))
      {
        auto cur = bzla_iter_binder_next(&nit);
        qlog("skip: %s (%s)\n",
             bzla_util_node2string(cur),
             bzla_util_node2string(cur->e[0]));
        cache.emplace(cur);
      }
      continue;
    }
    if (cache.find(q) != cache.end()) continue;
    if (d_deps.find(q) != d_deps.end()) continue;

    qlog("Dependencies for %s (%s):\n",
         bzla_util_node2string(q),
         bzla_util_node2string(q->e[0]));

    std::vector<BzlaNode *> free_vars;
    compute_variable_dependencies_aux(q, free_vars);
    assert(free_vars.size() > 0);

    d_deps.emplace(bzla_node_copy(d_bzla, q), free_vars);

    // Set dependencies for all quantifiers in same block.
    bzla_iter_binder_init(&nit, q);
    bzla_iter_binder_next(&nit);  // Skip `q`.
    while (bzla_iter_binder_has_next(&nit))
    {
      auto cur = bzla_iter_binder_next(&nit);
      assert(d_deps.find(cur) == d_deps.end());
      d_deps.emplace(bzla_node_copy(d_bzla, cur), free_vars);
      // Increment reference counts for all vars in `free_vars`.
      for (const auto fv : free_vars)
      {
        bzla_node_copy(d_bzla, fv);
      }
    }
  }
}

// TODO: add special values
void
QuantSolverState::collect_info(std::vector<BzlaNode *> &quantifiers)
{
  std::vector<BzlaNode *> visit;

  // TODO: cache visited constraints to avoid traversal of already seen
  // constraints
  BzlaPtrHashTableIterator it;
  bzla_iter_hashptr_init(&it, d_bzla->unsynthesized_constraints);
  bzla_iter_hashptr_queue(&it, d_bzla->assumptions);
  while (bzla_iter_hashptr_has_next(&it))
  {
    visit.push_back(static_cast<BzlaNode *>(bzla_iter_hashptr_next(&it)));
  }

  NodeSet cache;
  BzlaNode *cur;
  while (!visit.empty())
  {
    cur = bzla_node_real_addr(visit.back());
    visit.pop_back();

    if (cache.find(cur) == cache.end())
    {
      cache.emplace(cur);

      if (!cur->parameterized && !bzla_node_is_quantifier(cur)
          && !bzla_node_is_fun(cur))
      {
        BzlaSortId sort_id = bzla_node_get_sort_id(cur);

        auto &terms = d_term_map[sort_id];
        auto res    = std::find(terms.begin(), terms.end(), cur);
        if (res == std::end(terms))
        {
          terms.push_back(bzla_node_copy(d_bzla, cur));
        }
      }

      if (bzla_node_is_bv_const(cur))
      {
        BzlaSortId sort_id = bzla_node_get_sort_id(cur);

        // Add value if not already stored.
        auto &values = d_value_map[sort_id];
        auto res     = std::find(values.begin(), values.end(), cur);
        if (res == std::end(values))
        {
          values.push_back(bzla_node_copy(d_bzla, cur));
          qlog("found value: %s\n", bzla_util_node2string(cur));
        }
      }
      else if (bzla_node_is_var(cur) && bzla_node_is_bv(d_bzla, cur))
      {
        BzlaSortId sort_id = bzla_node_get_sort_id(cur);

        // Add value if not already stored.
        auto &consts = d_const_map[sort_id];
        auto res     = std::find(consts.begin(), consts.end(), cur);
        if (res == std::end(consts))
        {
          consts.push_back(bzla_node_copy(d_bzla, cur));
          qlog("found const: %s\n", bzla_util_node2string(cur));
        }
        d_constants.emplace(cur);
      }
      else if (bzla_node_is_quantifier(cur))
      {
        quantifiers.push_back(cur);
        visit.push_back(bzla_node_binder_get_body(cur));
        continue;
      }

      for (size_t i = 0; i < cur->arity; ++i)
      {
        visit.push_back(cur->e[i]);
      }
    }
  }

  // Sort term vectors in d_term_map by node ids.
  auto sort_by_id = [](const BzlaNode *t1, const BzlaNode *t2) -> bool {
    return bzla_node_get_id(bzla_node_real_addr(t1))
           < bzla_node_get_id(bzla_node_real_addr(t2));
  };
  for (auto [sort, consts] : d_term_map)
  {
    std::sort(consts.begin(), consts.end(), sort_by_id);
    for (size_t i = 0; i < consts.size(); ++i)
    {
      consts[i] = bzla_node_get_simplified(d_bzla, consts[i]);
    }
  }

  // Map may contain proxy nodes after first check-sat call, update term
  // vectors and filter remove simplified terms that are not constants anymore.
  for (auto &it : d_const_map)
  {
    auto consts = it.second;
    it.second.clear();
    for (size_t i = 0; i < consts.size(); ++i)
    {
      auto cur =
          bzla_node_real_addr(bzla_node_get_simplified(d_bzla, consts[i]));
      if (bzla_node_is_var(cur) && bzla_node_is_bv(d_bzla, cur))
      {
        it.second.push_back(bzla_node_copy(d_bzla, cur));
      }
      bzla_node_release(d_bzla, consts[i]);
    }
  }
}

BzlaSolverResult
QuantSolverState::check_ground_formulas()
{
  BzlaSolverResult res;
  NodeMap<BzlaNode *> assumptions;
  BzlaNode *lit;
  size_t i;
  double start;

  if (d_bzla->inconsistent)
  {
    qlog("Ground formulas inconsistent\n");
    return BZLA_RESULT_UNSAT;
  }

  start = bzla_util_time_stamp();
  ++d_statistics.num_ground_checks;

  if (d_opt_mode != BZLA_QUANT_MODE_LAZY)
  {
    for (auto [q, lit] : d_ce_literals)
    {
      if (is_inactive(q))
      {
        qlog("  inactive: %s\n", bzla_util_node2string(q));
        continue;
      }
      assumptions.emplace(lit, q);
    }
  }

  d_last_ground_check_ok = true;
  i = 0;
  while (true)
  {
    ++d_statistics.num_ground_checks_iterations;
    ++i;
    qlog("\n=================================================================");
    qlog("\nGround check: %zu (%zu assumptions):\n", i, assumptions.size());

    for (auto &p : assumptions)
    {
      qlog("  active: %s\n", bzla_util_node2string(p.second));
      assume(p.first);
    }

#ifdef QLOG
    //printf("\n");
    //bzla_dumpsmt_dump(d_bzla, stdout);
#endif

    res = check_sat_ground();

    qlog("Ground check: ");
    if (res == BZLA_RESULT_SAT)
    {
      qlog("sat\n");

#ifdef QLOG
      for (auto [q, sk] : d_skolems)
      {
        if (sk->arity == 0 && !bzla_hashptr_table_get(d_bzla->inputs, sk))
        {
          bzla_hashptr_table_add(d_bzla->inputs, bzla_node_copy(d_bzla, sk));
        }
      }
      for (auto [q, ic] : d_instantiation_constants)
      {
        if (!bzla_hashptr_table_get(d_bzla->inputs, ic))
        {
          bzla_hashptr_table_add(d_bzla->inputs, bzla_node_copy(d_bzla, ic));
        }
      }
      generate_model_ground();
      d_bzla->slv->api.print_model(d_bzla->slv, "smt2", stdout);
#endif

      reset_assumptions();
      if (d_opt_mode == BZLA_QUANT_MODE_EAGER_CHECK)
      {
        res = check_sat_ground();
      }
      break;
    }
    else
    {
      d_last_ground_check_ok = false;
      qlog("unsat\n");

      bool failed = false;
      /* Remove failed assumptions. */
      for (auto it = assumptions.begin(); it != assumptions.end();)
      {
        lit = it->first;
        if (bzla_failed_exp(d_bzla, lit))
        {
          qlog("  failed: %s (instance: %s)\n",
               bzla_util_node2string(it->second),
               bzla_util_node2string(find_original_instance(it->second)));
          failed = true;
          it     = assumptions.erase(it);
        }
        else
        {
          ++it;
        }
      }

      reset_assumptions();

      if (!failed)
      {
        break;
      }
    }
  }
  d_statistics.time_check_ground += bzla_util_time_stamp() - start;
  return res;
}

void
QuantSolverState::print_statistics() const
{
  BZLA_MSG(d_bzla->msg, 1, "");
  BZLA_MSG(d_bzla->msg, 1, "quantifier statistics:");
  BZLA_MSG(
      d_bzla->msg, 1, "  %zu ground checks", d_statistics.num_ground_checks);
  BZLA_MSG(d_bzla->msg,
           1,
           "  %zu ground check iterations",
           d_statistics.num_ground_checks_iterations);
  BZLA_MSG(d_bzla->msg,
           1,
           "  %zu CE checks",
           d_statistics.num_counterexample_checks);
  BZLA_MSG(d_bzla->msg,
           1,
           "  %zu value instantiation lemmas",
           d_statistics.num_value_inst_lemmas);
  BZLA_MSG(d_bzla->msg,
           1,
           "  %zu skolemization lemmas",
           d_statistics.num_skolemization_lemmas);
  BZLA_MSG(d_bzla->msg, 1, "  %zu CE lemmas", d_statistics.num_ce_lemmas);
  BZLA_MSG(d_bzla->msg,
           1,
           "  %zu synthesized qi lemmas",
           d_statistics.num_synth_qi_lemmas);
  BZLA_MSG(d_bzla->msg, 1, "  %zu mbqi lemmas", d_statistics.num_mbqi_lemmas);
}

void
QuantSolverState::print_time_statistics() const
{
  BZLA_MSG(d_bzla->msg, 1, "");
  BZLA_MSG(d_bzla->msg, 1, "quantifier time statistics:");
  BZLA_MSG(
      d_bzla->msg, 1, "  %.1f seconds check-sat", d_statistics.time_check_sat);
  BZLA_MSG(d_bzla->msg,
           1,
           "    %.1f seconds ground checks",
           d_statistics.time_check_ground);
  BZLA_MSG(d_bzla->msg, 1, "    %.1f get active", d_statistics.time_get_active);
  BZLA_MSG(d_bzla->msg,
           1,
           "    %.1f seconds synthesize terms",
           d_statistics.time_synthesize_terms);
  BZLA_MSG(d_bzla->msg,
           1,
           "    %.1f seconds CE checks",
           d_statistics.time_check_counterexamples);
}

///////////////////////////////////////////////////////////////////////////////

static BzlaSolverResult
check_sat_quant_solver(BzlaQuantSolver *slv)
{
  assert(slv);
  assert(slv->kind == BZLA_QUANT_SOLVER_KIND);
  assert(slv->bzla);
  assert(slv->bzla->qslv == (BzlaSolver *) slv);

  bool done;
  double start;
  BzlaSolverResult res;

  // debug
  bzla_opt_set(slv->bzla, BZLA_OPT_PRETTY_PRINT, 0);

  start                   = bzla_util_time_stamp();
  QuantSolverState &state = *slv->d_state.get();

  std::vector<BzlaNode *> quantifiers;
  state.reset();
  state.collect_info(quantifiers);
  state.compute_variable_dependencies(quantifiers);

  while (true)
  {
    res = state.check_ground_formulas();
    if (res == BZLA_RESULT_SAT)
    {
      qlog("\n");
      state.generate_model_ground();
      done = state.check_active_quantifiers();
      if (!state.added_new_lemmas())
      {
        if (done)
        {
          qlog("** No new counterexamples found, all quantifiers inactive\n");
          res = BZLA_RESULT_SAT;
        }
        else
        {
          qlog("** No new lemmas added\n");
          res = BZLA_RESULT_UNKNOWN;
        }
        break;
      }
    }
    else
    {
      res = BZLA_RESULT_UNSAT;
      break;
    }
  }

  state.d_statistics.time_check_sat += bzla_util_time_stamp() - start;

  return res;
}

static BzlaSolverResult
check_sat_portfolio(BzlaQuantSolver *slv)
{
  BzlaSolverResult res = BZLA_RESULT_UNKNOWN;

  std::vector<BzlaOptQuantMode> modes = {BZLA_QUANT_MODE_LAZY,
                                         BZLA_QUANT_MODE_EAGER_CHECK,
                                         BZLA_QUANT_MODE_EAGER_REUSE,
                                         BZLA_QUANT_MODE_EAGER};

  // Try modes in sequential portfolio configuration as long as the check-sat
  // call returns unknown.
  for (auto mode : modes)
  {
    bzla_opt_set(slv->bzla, BZLA_OPT_QUANT_MODE, mode);
    res = check_sat_quant_solver(slv);
    if (res != BZLA_RESULT_UNKNOWN)
    {
      break;
    }
  }

  // Reset mode to portfolio.
  bzla_opt_set(slv->bzla, BZLA_OPT_QUANT_MODE, BZLA_QUANT_MODE_PORTFOLIO);

  return res;
}

static BzlaQuantSolver *
clone_quant_solver(Bzla *clone, Bzla *bzla, BzlaNodeMap *exp_map)
{
  (void) clone;
  (void) bzla;
  (void) exp_map;
  return 0;
}

static void
delete_quant_solver(BzlaQuantSolver *slv)
{
  assert(slv);
  assert(slv->kind == BZLA_QUANT_SOLVER_KIND);
  assert(slv->bzla);
  delete slv;
}

static void
generate_model_quant_solver(BzlaQuantSolver *slv,
                            bool model_for_all_nodes,
                            bool reset)
{
  (void) slv;
  (void) model_for_all_nodes;
  (void) reset;
}

static void
print_stats_quant_solver(BzlaQuantSolver *slv)
{
  slv->d_state->print_statistics();
}

static void
print_time_stats_quant_solver(BzlaQuantSolver *slv)
{
  slv->d_state->print_time_statistics();
}

static void
print_model_quant_solver(BzlaQuantSolver *slv, const char *format, FILE *file)
{
  (void) slv;
  (void) format;
  (void) file;
}

}  // namespace bzla

BzlaSolver *
bzla_new_quantifier_solver(Bzla *bzla)
{
  assert(bzla);

  using namespace bzla;

  BzlaQuantSolver *slv = new BzlaQuantSolver();
  slv->d_state.reset(new QuantSolverState(bzla));

  slv->kind      = BZLA_QUANT_SOLVER_KIND;
  slv->bzla      = bzla;
  slv->api.clone = (BzlaSolverClone) clone_quant_solver;
  slv->api.delet = (BzlaSolverDelete) delete_quant_solver;
  if (bzla_opt_get(bzla, BZLA_OPT_QUANT_MODE) == BZLA_QUANT_MODE_PORTFOLIO)
  {
    slv->api.sat = (BzlaSolverSat) check_sat_portfolio;
  }
  else
  {
    slv->api.sat = (BzlaSolverSat) check_sat_quant_solver;
  }
  slv->api.generate_model =
      (BzlaSolverGenerateModel) generate_model_quant_solver;
  slv->api.print_stats = (BzlaSolverPrintStats) print_stats_quant_solver;
  slv->api.print_time_stats =
      (BzlaSolverPrintTimeStats) print_time_stats_quant_solver;
  slv->api.print_model = (BzlaSolverPrintModel) print_model_quant_solver;

  BZLA_MSG(bzla->msg, 1, "enabled quant engine");

  return (BzlaSolver *) slv;
}
