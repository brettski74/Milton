# Makefile for PSC Web UI components

BASEDIR=../

# Include configuration and rules from parent
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

.PHONY: install install-dirs check-perl clean

# Perl scripts to install
PERL_SCRIPTS=psc_web.pl

REL_PERL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(PERL_SCRIPTS))

# Perl modules to install
PERL_MODULES=$(wildcard */*.pm) $(wildcard */*/*.pm)

REL_PERL_MODULES=$(patsubst %,$(LIBDIR)/%,$(PERL_MODULES))

install: $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS)

# Create installation directories
install-dirs:
	@echo "Creating Web UI installation directories..."
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)

# Clean up
clean:
	@echo "Cleaning Web UI components..." 
	rm -f $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS)
