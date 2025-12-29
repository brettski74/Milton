# Makefile for PSC Web UI components

BASEDIR=../

# Include configuration and rules from parent
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

IMAGES_DIR=$(SHAREDIR)/webui/public/images
TEMPLATES_DIR=$(SHAREDIR)/webui/templates

.PHONY: install install-dirs check-perl clean

# Perl scripts to install
PERL_SCRIPTS=milton.pl

REL_PERL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(PERL_SCRIPTS))

TEMPLATES=$(wildcard templates/*.html.ep)
REL_TEMPLATES=$(patsubst templates/%,$(TEMPLATES_DIR)/%,$(TEMPLATES))
TEMPLATE_PERMS=0644

IMAGES=$(wildcard public/images/*.png)
REL_IMAGES=$(patsubst public/images/%,$(IMAGES_DIR)/%,$(IMAGES))
IMAGE_PERMS=0644

# Perl modules to install
PERL_MODULES=$(wildcard */*.pm) $(wildcard */*/*.pm)

REL_PERL_MODULES=$(patsubst %,$(LIBDIR)/%,$(PERL_MODULES))

$(BINDIR) $(LIBDIR) $(TEMPLATES_DIR): install-dirs

$(TEMPLATES_DIR): install-dirs

$(IMAGES_DIR)/%: public/images/% $(IMAGES_DIR)
	@cp -v $< $@
	@chmod $(IMAGE_PERMS) $@

$(TEMPLATES_DIR)/%: templates/% $(TEMPLATES_DIR)
	@cp -v $< $@
	@chmod $(TEMPLATE_PERMS) $@

install: $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS) $(REL_TEMPLATES) $(REL_IMAGES)
	@echo "################################################################################"
	@echo "# Web UI installation complete!"
	@echo "################################################################################"

# Create installation directories
install-dirs:
	@echo "################################################################################"
	@echo "# Creating Web UI installation directories..."
	@echo "################################################################################"
	@mkdir -p $(BINDIR) $(LIBDIR) $(TEMPLATES_DIR) $(IMAGES_DIR)

# Clean up
clean:
	@echo "################################################################################"
	@echo "# Cleaning Web UI components..." 
	@echo "################################################################################"
	rm -f $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS)

reallyclean: clean