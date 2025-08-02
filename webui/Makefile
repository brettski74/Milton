# Makefile for PSC Web UI components

BASEDIR=../

# Include configuration and rules from parent
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

TEMPLATES_DIR=$(SHAREDIR)/webui/templates

.PHONY: install install-dirs check-perl clean

# Perl scripts to install
PERL_SCRIPTS=psc_web.pl

REL_PERL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(PERL_SCRIPTS))

TEMPLATES=$(wildcard templates/*.html.ep)
REL_TEMPLATES=$(patsubst templates/%,$(TEMPLATES_DIR)/%,$(TEMPLATES))
TEMPLATE_PERMS=0644

# Perl modules to install
PERL_MODULES=$(wildcard */*.pm) $(wildcard */*/*.pm)

REL_PERL_MODULES=$(patsubst %,$(LIBDIR)/%,$(PERL_MODULES))

$(BINDIR) $(LIBDIR) $(TEMPLATES_DIR): install-dirs

$(TEMPLATES_DIR): install-dirs

$(TEMPLATES_DIR)/%: templates/% $(TEMPLATES_DIR)
	@cp $< $@
	@chmod $(TEMPLATE_PERMS) $@

install: $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS) $(REL_TEMPLATES)
	@echo "Web UI Installation Complete!"

# Create installation directories
install-dirs:
	@echo "Creating Web UI installation directories..."
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)
	@mkdir -p $(TEMPLATES_DIR)

# Clean up
clean:
	@echo "Cleaning Web UI components..." 
	rm -f $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS)
