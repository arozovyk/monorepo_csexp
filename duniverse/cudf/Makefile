include Makefile.config

NAME = cudf

DOC = doc/cudf-check.1
SOURCES = $(wildcard */*.ml */*.mli */*.mll */*.mly)
C_LIB_DIR = c-lib
C_LIB_SOURCES = $(wildcard $(C_LIB_DIR)/*.c $(C_LIB_DIR)/*.h)

ifeq ($(DESTDIR),)
INSTALL = dune install
UNINSTALL = dune uninstall
else
DESTDIR:=$(DESTDIR)/
INSTALL = dune install --destdir=$(DESTDIR)
UNINSTALL = dune uninstall --destdir=$(DESTDIR)
endif

DIST_DIR = $(NAME)-$(VERSION)
DIST_TARBALL = $(DIST_DIR).tar.gz

all: doc/cudf-check.1
	dune build

doc/cudf-check.1: doc/cudf-check.pod
	$(MAKE) -C doc/

.PHONY: c-lib c-lib-opt doc
c-lib:
	make -C $(C_LIB_DIR) all
c-lib-opt:
	make -C $(C_LIB_DIR) opt

clean:
	make -C $(C_LIB_DIR) clean
	make -C doc/ clean
	dune clean
	rm -rf $(NAME)-*.gz $(NAME)_*.gz $(NAME)-*/

top-level:
	ledit ocaml -init ./.ocamlinit-cudf

headers: header.txt .headache.conf
	headache -h header.txt -c .headache.conf $(SOURCES) $(C_LIB_SOURCES)

test:
	dune runtest
c-lib-test:
	make -C $(C_LIB_DIR) test

tags: TAGS
TAGS: $(SOURCES)
	otags $^

install:
	$(INSTALL)
	if [ -f $(C_LIB_DIR)/cudf.o ] ; then \
		$(MAKE) -C c-lib/ -e install ; \
	fi

uninstall:
	$(UNINSTALL)
	-rmdir -p $(DESTDIR)$(OCAMLLIBDIR) $(DESTDIR)$(BINDIR)

dist: ./$(DIST_TARBALL)
./$(DIST_TARBALL):
	git archive --format=tar --prefix=$(DIST_DIR)/ HEAD | gzip > $@
	@echo "Distribution tarball: ./$(DIST_TARBALL)"

rpm: ./$(DIST_TARBALL)
	rpmbuild --nodeps -ta $<

distcheck: ./$(DIST_TARBALL)
	tar xzf $<
	$(MAKE) -C ./$(DIST_DIR) all
	$(MAKE) -C ./$(DIST_DIR) test
	$(MAKE) -C ./$(DIST_DIR)/$(C_LIB_DIR)/ all
	$(MAKE) -C ./$(DIST_DIR) install DESTDIR=$(CURDIR)/$(DIST_DIR)/tmp
	rm -rf ./$(DIST_DIR)

doc:
	dune build @doc

world: all c-lib c-lib-opt doc

.PHONY: all world clean top-level headers test tags install uninstall
.PHONY: dep rpm c-lib c-lib-opt dist doc
.NOTPARALLEL:
