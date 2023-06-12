(lang dune 3.0)

(use_standard_c_and_cxx_flags true)

(generate_opam_files true)

(name bls12-381)

(homepage "https://nomadic-labs.gitlab.io/cryptography/ocaml-bls12-381/bls12-381/")
(source (uri "git+https://gitlab.com/nomadic-labs/cryptography/ocaml-bls12-381.git"))
; (source (gitlab nomadic-labs/cryptography/ocaml-bls12-381))
; Dune doesn't allow the `source` field in `dune-project` to contain a link in
; a format other than `user/repo`. See
; https://github.com/ocaml/dune/issues/6723.
(license MIT)
(authors "Danny Willems <be.danny.willems@gmail.com>")
(maintainers "Danny Willems <be.danny.willems@gmail.com>")
(bug_reports "https://gitlab.com/nomadic-labs/cryptography/ocaml-bls12-381/-/issues")

(package
 (name bls12-381)
 (synopsis "Implementation of BLS12-381 and some cryptographic primitives built
on top of it")
 (depends
  (ocaml (>= 4.08))
  (zarith (and (>= 1.10) (< 2.0)))
  (zarith_stubs_js :with-test)
  (hex (>= 1.3.0))
  (alcotest :with-test)
  integers
  (integers_stubs_js :with-test)))
