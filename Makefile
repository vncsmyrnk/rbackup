SRCDIR = .
RBACKUP = $(SRCDIR)/rbackup

PREFIX ?= /usr/local
DESTDIR ?=

INSTALL ?= install
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = $(INSTALL) -m 644

all: $(RBACKUP)

$(RBACKUP): $(SRCDIR)/rbackup.elv
	elvish -compileonly $^
	@cp $^ $@

clean:
	@rm -rf $(RBACKUP)

check:
	@prove -v

install: all
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/share/zsh/site-functions
	$(INSTALL_PROGRAM) $(RBACKUP) $(DESTDIR)$(PREFIX)/bin
	$(INSTALL_DATA) $(SRCDIR)/completions/zsh $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_rbackup

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/rbackup
	rm -f $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_rbackup

.PHONY: clean check install uninstall
