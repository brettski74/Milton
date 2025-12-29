# Makefile for PSC CLI components

BASEDIR=../

# Include configuration and rules from parent
-include $(BASEDIR)/config.mk
-include $(BASEDIR)/rules.mk

.PHONY: install install-dirs check-perl clean

TEST_DIRS=$(shell find . -type d -name t)

# Perl scripts to install
PERL_SCRIPTS=psc.pl milton-setup.pl
TOOL_SCRIPTS=tools/csv2csv.pl tools/csv2perl.pl

REL_PERL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(PERL_SCRIPTS))
REL_TOOL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(TOOL_SCRIPTS))

# Perl modules to install
# Hacky - need better way to do arbitrary depth subdirectories, but this works for now
PERL_MODULES=$(wildcard */*.pm) $(wildcard */*/*.pm) $(wildcard */*/*/*.pm)

REL_PERL_MODULES=$(patsubst %,$(LIBDIR)/%,$(PERL_MODULES))

test:
	@echo "Running tests..."
	@prove -I. -l $(TEST_DIRS)

test-verbose:
	@echo "Running tests..."
	@prove -I. -lv $(TEST_DIRS)

# Create installation directories
install-dirs:
	@echo "Creating CLI installation directories..."
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)

# Install CLI components
install: $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS)
	@echo "CLI installation complete!"

install-tools: $(REL_TOOL_SCRIPTS)
	@echo "Tools installation complete!"

# Clean up
clean:
	@echo "Cleaning CLI components..." 
	rm -f $(REL_PERL_SCRIPTS) $(REL_TOOL_SCRIPTS) $(REL_PERL_MODULES)
