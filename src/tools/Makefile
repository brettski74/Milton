# Makefile for Milton tools components

BASEDIR=../..

# Include configuration and rules from parent
-include $(BASEDIR)/config.mk
-include $(BASEDIR)/rules.mk

.PHONY: install install-dirs check-perl clean

# Perl scripts to install
PERL_SCRIPTS=csv2csv.pl csv2perl.pl mledit.pl

REL_PERL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(PERL_SCRIPTS))

# Create installation directories
install-dirs:
	@echo "################################################################################"
	@echo "# Creating tool installation directories..."
	@echo "################################################################################"
	@mkdir -p $(BINDIR)

# Install CLI components
install: $(REL_PERL_SCRIPTS)
	@echo "################################################################################"
	@echo "# Tool installation complete!"
	@echo "################################################################################"

# Clean up
clean:
	@echo "################################################################################"
	@echo "# Cleaning tool components..." 
	@echo "################################################################################"
	rm -f $(REL_PERL_SCRIPTS)