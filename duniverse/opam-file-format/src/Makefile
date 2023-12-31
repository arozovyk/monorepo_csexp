all: opam-file-format.cmxa opam-file-format.cma

%.ml: %.mll
	ocamllex $<

EMPTY=
SPACE=$(EMPTY) $(EMPTY)
OCAML_VERSION:=$(firstword $(subst ~, ,$(subst +, ,$(shell ocamlc -version))))
ifeq ($(OCAML_VERSION),)
OCAML_VERSION:=0
else
OCAML_VERSION:=$(subst ., ,$(OCAML_VERSION))
OCAML_VERSION:=$(subst $(SPACE),,$(firstword $(OCAML_VERSION))$(foreach i,$(wordlist 2,$(words $(OCAML_VERSION)),$(OCAML_VERSION)),$(if $(filter 0 1 2 3 4 5 6 7 8 9,$(i)),0,)$(i)))
endif

ifeq ($(shell test $(OCAML_VERSION) -ge 40202 || echo no-attributes),)
PP=
else
PP=-pp 'sed -e s/\\[@@\\?ocaml[^]]*\\]//'
endif

show:
	echo $(OCAML_VERSION)

opamParserTypes.cmi: opamParserTypes.cmo

%.ml %.mli: %.mly
	ocamlyacc $<

%.cmi: %.mli
	ocamlc -c $(PP) $<

%.cmo: %.ml
	ocamlc -c $(PP) $<

%.cmx: %.ml
	ocamlopt -c $(PP) $<

MODULES = opamParserTypes opamBaseParser opamLexer opamParser opamPrinter

GENERATED = $(patsubst %.mly,%.ml,$(wildcard *.mly)) \
            $(patsubst %.mly,%.mli,$(wildcard *.mly)) \
            $(patsubst %.mll,%.ml,$(wildcard *.mll)) \
	    META

opam-file-format.cma: $(addsuffix .cmo,$(MODULES))
	ocamlc -a $^ -o $@

opam-file-format.cmxa: $(addsuffix .cmx,$(MODULES))
	ocamlopt -a $^ -o $@

opam-file-format.cmxs: $(addsuffix .cmx,$(MODULES))
	ocamlopt -shared $^ -o $@

META: META.in ../opam-file-format.opam $(wildcard *.cm*)
	sed -e 's/VERSION/$(shell sed -ne "s/^version: //p" ../opam-file-format.opam)/' \
	    $(if $(wildcard *.cmx*),,-e '/archive(native)/d') \
	    $(if $(wildcard *.cma),,-e '/archive(byte)/d') $< > $@

.PHONY: clean
clean:
	rm -f *.cm* *.o *.a $(GENERATED) .depend .merlin

.depend: *.ml *.mli $(GENERATED)
	ocamldep $(PP) *.mli *.ml > .depend

-include .depend
