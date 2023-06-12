#!/bin/bash -xue

. .github/scripts/preamble.sh

wget "http://caml.inria.fr/pub/distrib/ocaml-${OCAML_VERSION%.*}/ocaml-$OCAML_VERSION.tar.gz"
tar -xzf "ocaml-$OCAML_VERSION.tar.gz"

case "${OCAML_VERSION%.*}" in
  4.02) PATCHES='db1c4d4cdc9ede9b1178a262d1f4d93663eef2f3 9de2b77472aee18a94b41cff70caee27fb901225';;
  4.03) PATCHES='55164ab7dacb0e4a67f7b9df3db54b8d2c815719 3935c985563f823a952a0a56c90d6b9af8919bf5 a8b2cc3b40f5269ce8525164ec2a63b35722b22b';;
  4.04) PATCHES='5edfbe9ffbd60ddfe156ef658e6562081d260f55 a871c905626f9ce2f428ce54a542fd23682cb880 6bcff7e6ce1a43e088469278eb3a9341e6a2ca5b';;
  4.05) PATCHES='5facd7513877dd884aa4036233a633550a48a1a9 ead74c13d7c3698f966cd6f40331a91b844d2074 50c2d1275e537906ea144bd557fde31e0bf16e5f';;
  4.06) PATCHES='cbf0fc22670ac8ce7dfc2ec5249a91e03e8ae8c8 30b66dbe3f7394b2a69cdd69092143b215ad4ae9 137a4ad167f25fe1bee792977ed89f30d19bcd74';;
  4.07) PATCHES='4135828a4b66eb7403d68839da701257c0ccd31e 00b8c4d503732343d5d01761ad09650fe50ff3a0';;
  4.08) PATCHES='e322556b0a9097a2eff2117476193b773e1b947f 17df117b4939486d3285031900587afce5262c8c';;
  4.09) PATCHES='8eed2e441222588dc385a98ae8bd6f5820eb0223';;
  4.10) PATCHES='4b4c643d1d5d28738f6d900cd902851ed9dc5364';;
  4.11) PATCHES='dd28ac0cf4365bd0ea1bcc374cbc5e95a6f39bea';;
  4.12) PATCHES='1eeb0e7fe595f5f9e1ea1edbdf785ff3b49feeeb';;
  *) PATCHES='';;
esac

cd "ocaml-$OCAML_VERSION"
for sha in $PATCHES; do
  curl -sL "https://github.com/ocaml/ocaml/commit/$sha.patch" -o "../$sha.patch"
  patch -p1 -i "../$sha.patch"
done

if [[ $OPAM_TEST -ne 1 ]] ; then
  if [[ -e configure.ac ]]; then
    CONFIGURE_SWITCHES="--disable-debugger --disable-debug-runtime"
    if [ "$SOLVER" != "z3" ]; then
      CONFIGURE_SWITCHES="$CONFIGURE_SWITCHES --disable-ocamldoc"
    fi
    if [[ ${OCAML_VERSION%.*} = '4.08' ]]; then
      CONFIGURE_SWITCHES="$CONFIGURE_SWITCHES --disable-graph-lib"
    fi
  else
    CONFIGURE_SWITCHES="-no-graph -no-debugger"
    if [ "$SOLVER" != "z3" ]; then
      CONFIGURE_SWITCHES="$CONFIGURE_SWITCHES -no-ocamldoc"
    fi
    if [[ ${OCAML_VERSION%.*} = '4.08' ]]; then
      CONFIGURE_SWITCHES="$CONFIGURE_SWITCHES --disable-graph-lib"
    fi
    if [[ "$OCAML_VERSION" != "4.02.3" ]] ; then
      CONFIGURE_SWITCHES="$CONFIGURE_SWITCHES -no-ocamlbuild"
    fi

  fi
fi

./configure --prefix $OCAML_LOCAL ${CONFIGURE_SWITCHES:-}

if [[ $OPAM_TEST -eq 1 ]] ; then
  make -j 4 world.opt
else
  make world.opt
fi

make install

cd ..
rm -rf "ocaml-$OCAML_VERSION"
