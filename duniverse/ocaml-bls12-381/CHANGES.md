### Unreleased

- Add constraint `with-test` for ff-pbt in the OPAM definition. It is fixed in
  ocaml/opam-repository for bls12-381.6.0.1, but not in the release tag here.
  There is therefore an inconsistency between the OPAM file definitions. As it is
  not related to the code, I suggest to leave it like this.
- CI: replace opam reinstall by opam remove/install + use latest opam because of getting solver timeout
- Get rid of ocaml-ff dependency, and import `Ff_sig` and `Ff_pbt` in the repository

### 6.0.1

- Move to dune 3.0.0 (https://gitlab.com/nomadic-labs/cryptography/ocaml-bls12-381/-/merge_requests/208)
- Drop alpine 3.14 and alpine 3.15 (24ec4f9bb95a661eb293c0b7e2afa28cf3cf532f)
- Support OCaml 5.0.0 (https://gitlab.com/nomadic-labs/cryptography/ocaml-bls12-381/-/merge_requests/210)
- Fix NPM registry publishing
  (https://gitlab.com/nomadic-labs/cryptography/ocaml-bls12-381/-/merge_requests/209)
- CI: add a check on PR verifying CHANGES.md has been modified
- Tests: fix emcc dependency when installing the library with --with-test. See
  https://github.com/ocaml/opam-repository/pull/22753#discussion_r1062468218
- CI: test opam install --with-test
- CI: merge alpine and debian script
- OPAM: add missing dev-repo and fix bug-reports url
- Support more 64bits platforms like ppc64
- Conflicts when the platform only supports bytecode
- Use `uname -m` instead of `uname --machine` as the latter is not standard.
- Fix assembly optimisations compilation for arm64 by checking the output of
  `uname -m` equals `aarch64`. Same for `amd64`.

### 6.0.0

- Remove fft related routines from Fr, G1 and G2, move in
  https://gitlab.com/nomadic-labs/cryptography/privacy-team/bls12-381-polynomial (https://gitlab.com/nomadic-labs/cryptography/ocaml-bls12-381/-/merge_requests/207)

### 5.0.0-rc.0

#### API changes

- G1/G2: add `compressed_size_in_bytes`
- Remove Poseidon, Poseidon128, Rescue and signature to move into independent repositories

### 4.0.0

#### API changes

- Fr: change API of inplace operators

#### New features

- Blst: modify pippenger to work with contiguous arrays of byte sequences and
  affine points (3c8ae8a3c2e8735101c71dbbdcaa3c853e30b891).
- `Bls12_381.G1.pippenger_with_affine_array` and
  `Bls12_381.G2.pippenger_with_affine_array` works with the contiguous version
  from blst (a37c1b2ba95a807544b739ade0edf334f4de2c7d).
- Move some auxiliaries C functions into blst (`blst_fr_is_equal`,
  `blst_fr_is_zero`, `blst_fr_is_one`, `blst_fp12_is_zero`,
  `blst_fp12_set_to_one`, `blst_fp2_set_to_one`, `blst_fr_set_to_zero`,
  `blst_fr_set_to_one`) and use fastest routines provided by blst internals
  (f914a4a20f53274182767b23ce8e67de59dfef2e).
- Poseidon: implement a generic version of Poseidon, including optimisations
  from https://eprint.iacr.org/2022/462
  (dd070dde05204a04f2ad0c4ac3e4576d93deaa3e,
  fa4b9418e1a2052ffca22287fd036f73e33b99a5,
  e9c33636b6bbc0e1f94d84b1841cc25fcfcce3f4,
  a577ea393431abd7c0b8d840574b6e145934d6cd,
  1bdf228111fa7e81e445e4450939ca20ade40949,
  48cbc33a7dca01f6e6493c8a7edb1edfc74dcb77)
- Publish NPM package automatically in the CI when a tag is created
  (1fc351fada8e1cca5beb022cad0a694b2d0d1c5f,
  128d090c5ba72b48061831812330c22823fc646a,
  2dd4863705b0608831892b61e109521c9d80b46f)
- Upgrade blst to 0.3.7
- Fr: use `blst_fr_cneg` instead of `blst_fr_sub`  for `Fr.neg`
- Fr: use `blst_fr_sqr` instead of `blst_fr_mul`  for `Fr.square_inplace`

#### Performance improvements

- Remove some extra allocations performed on the heap when not required
  (e3fac8159bb39af8d877ad8e23f7db74e19ee2cb)
- `blst_fp12_pow`: moving checks if the exponent is one or zero in the C code
  (ce2a3429d86506d8d17c5be27334bbd82e8f9e9a)

#### Bugfix

- `Fp12.one` was set to a generator of the prime subgroup.
- Signature: copy dst before calling blst_pairing_init. Bug
  https://gitlab.com/dannywillems/ocaml-bls12-381/-/issues/63 reintroduced in
  https://gitlab.com/dannywillems/ocaml-bls12-381/-/commit/bb1d1c5123ec66f5e2ac34b4c91e2baadf9b05c4
  and wrong custom block structured used (blst_fp12_ops instead of
  blst_pairing_ops) introduced in
  https://gitlab.com/dannywillems/ocaml-bls12-381/-/commit/aa6c9566386c03bde0028fe64fb8c599a41f403f
  which causes memleaks because a pointer is not free correctly.

### 3.0.2

- OPAM: remove JS stubs while running tests are not required
  (68584de662650923864c16ab2699af3b62ff07bf)

### 3.0.1

#### Bugfix

- Fix `Bls12_381.built_with_blst_portable`. Detect using `Sys.getenv_opt` was not
  a working solution. Projects relying on the value must update the library.
- Fix `GT.check_bytes`, see https://github.com/supranational/blst/issues/108 and
  https://github.com/dannywillems/ocaml-bls12-381/pull/4

#### MISC

- Replace `GT.one` with the hexadecimal representation of the generator, instead
  of computing using `Pairing.pairing`

### 0.4.0

#### Changes

+ Split packages in bls12-381-gen, bls12-381, bls12-381-unix, bls12-381-js,
  bls12-381-js-gen. bls12-381 is a virtual package and
  bls12-381-unix/bls12-381-js are the actual implementation for respectively the
  UNIX and JavaScript versions. bls12-381-gen and bls12-381-js-gen are helpers.
- Remove version field in opam files.
- Update to ff-sig.0.6.1, ff.0.6.1 and ff-pbt.0.6.1
