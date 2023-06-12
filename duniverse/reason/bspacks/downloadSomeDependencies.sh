set -xeo pipefail

THIS_SCRIPT_DIR="$(cd "$( dirname "$0" )" && pwd)"

if [ -z ${OCAML_VERSION+x} ]; then
  echo "OCAML_VERSION not defined, defaulting to '4.06.1'..."
  OCAML_VERSION=4.06.1
fi

echo "**This script is switching you to ocaml ${OCAML_VERSION} for the subsequent bspacking. Please switch back to your own version afterward. Thanks!**\n"

# switch to 4.06.1. Bspacking means we're sending the final bundle to BuckleScript, which is still on 4.02
opam switch $OCAML_VERSION

# =============
# first step, build ocaml-migrate-parsetree
# =============
eval $(opam config env)

OMP_ARTIFACTS_DIR="$THIS_SCRIPT_DIR/ocaml-migrate-parsetree"

rm -rf $OMP_ARTIFACTS_DIR
mkdir $OMP_ARTIFACTS_DIR

# ocaml-migrate-parsetree uses jbuilder to build, and having jBuilder inside the
# reason repo clashes with reason's own jbuilder build
TEMP_DIR_FOR_OMP=`mktemp -d`
echo "cloning ocaml-migrate-parsetree into $TEMP_DIR_FOR_OMP"
git clone https://github.com/ocaml-ppx/ocaml-migrate-parsetree.git $TEMP_DIR_FOR_OMP

git clone https://github.com/ocaml-ppx/ppx_derivers $TEMP_DIR_FOR_OMP/ppx_derivers

pushd $TEMP_DIR_FOR_OMP

# pin it at a certain tag
git checkout v1.5.0
# if there's any error, check if you have everything installed. You should
# already from opam pin-ing the reason repo (which depends on ocaml-migrate-parsetree)

pushd ppx_derivers
git checkout 1.2.1
make
popd

make

pushd ./_build/default/src

rm -rf ./*.cm*
rm -rf ./*.o
rm -rf ./*.a

# # bspack needs the fully processed files with ppx already applied to them, and
# # jBuilder keeps them around in files like `x.pp.ml`, so rename them to `x.ml`
for i in ./*.pp.{ml,mli}; do mv $i ${i/.pp/}; done

popd
popd

mv $TEMP_DIR_FOR_OMP/* $OMP_ARTIFACTS_DIR
