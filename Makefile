SRCDIR = .

PREFIX ?= /usr/local
DESTDIR ?=

INSTALL ?= install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644

all: $(SRCDIR)/rbackup $(shell find $(SRCDIR)/lib -type f)
	elvish -compileonly $?

check:
	@prove -v

install: all
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/zsh/site-functions
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/elvish/lib/rbackup
	$(INSTALL_PROGRAM) $(SRCDIR)/rbackup $(DESTDIR)$(PREFIX)/bin
	$(INSTALL_DATA) $(SRCDIR)/lib/* $(DESTDIR)$(PREFIX)/share/elvish/lib/rbackup
	$(INSTALL_DATA) $(SRCDIR)/completions/zsh $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_rbackup

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/rbackup
	rm -f $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_rbackup
	rm -rf $(DESTDIR)$(PREFIX)/share/elvish/lib/rbackup

nix:
	nix build .# -L

develop:
	nix develop

.PHONY: clean check install uninstall
