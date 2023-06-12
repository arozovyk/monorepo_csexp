#!/usr/bin/env bash

set -e

export OCAML_VERSION="${1}"

make clean-for-ci
opam switch "${OCAML_VERSION}"
eval `opam config env`
opam update
opam install -y dune
# Our constraints are wrong I believe. We need this version.
opam install -y menhir
opam pin add -y reason .
opam pin add -y rtop .
make test-ci
git diff --exit-code
