SRCDIR = .

PREFIX ?= /usr/local
DESTDIR ?=

INSTALL ?= install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644

DATE ?= $(shell date +%Y\-%m\-%d)

all: $(SRCDIR)/rbackup $(shell find $(SRCDIR)/lib -type f)
	elvish -compileonly $?

check:
	@prove -v

install: all
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/zsh/site-functions
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/elvish/lib/rbackup
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/man/man1
	$(INSTALL_PROGRAM) $(SRCDIR)/rbackup $(DESTDIR)$(PREFIX)/bin
	$(INSTALL_DATA) $(SRCDIR)/lib/* $(DESTDIR)$(PREFIX)/share/elvish/lib/rbackup
	$(INSTALL_DATA) $(SRCDIR)/completions/zsh $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_rbackup
	$(INSTALL_DATA) $(SRCDIR)/man/rbackup.1 $(DESTDIR)$(PREFIX)/share/man/man1

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/rbackup
	rm -f $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_rbackup
	rm -rf $(DESTDIR)$(PREFIX)/share/elvish/lib/rbackup
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/rbackup.1

doc: $(SRCDIR)/man/rbackup.1

$(SRCDIR)/man/rbackup.1: $(SRCDIR)/man/rbackup.1.md
	pandoc -s -f markdown -t man -V footer="rbackup $(VERSION)" -V date="$(DATE)" $< -o $@

nix:
	nix build .# -L

develop:
	nix develop

.PHONY: clean check doc install uninstall
