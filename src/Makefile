# Makefile for PSC CLI components

BASEDIR=../

# Include configuration and rules from parent
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

.PHONY: install install-dirs check-perl clean

TEST_DIRS=$(shell find . -type d -name t)

# Perl scripts to install
PERL_SCRIPTS=psc.pl milton-setup.pl
TOOL_SCRIPTS=tools/csv2csv.pl tools/csv2perl.pl tools/milton-edit.pl

REL_PERL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(PERL_SCRIPTS))
REL_TOOL_SCRIPTS=$(patsubst %.pl,$(BINDIR)/%,$(TOOL_SCRIPTS))

# Perl modules to install
# Hacky - need better way to do arbitrary depth subdirectories, but this works for now
PERL_MODULES=$(wildcard */*.pm) $(wildcard */[A-Z]*/*.pm) $(wildcard */*/[A-Z]*/*.pm)

REL_PERL_MODULES=$(patsubst %,$(LIBDIR)/%,$(PERL_MODULES))

test:
	@echo "################################################################################"
	@echo "# Running CLI tests..."
	@echo "################################################################################"
	@prove -I. -l $(TEST_DIRS)

test-verbose:
	@echo "################################################################################"
	@echo "# Running CLI tests..."
	@echo "################################################################################"
	@prove -I. -lv $(TEST_DIRS)

# Create installation directories
install-dirs:
	@echo "################################################################################"
	@echo "# Creating CLI installation directories..."
	@echo "################################################################################"
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)

# Install CLI components
install: $(REL_PERL_MODULES) $(REL_PERL_SCRIPTS) install-tools
	@echo "################################################################################"
	@echo "# CLI installation complete!"
	@echo "################################################################################"

install-tools:
	$(MAKE) -C tools install

# Clean up
clean:
	@echo "################################################################################"
	@echo "# Cleaning CLI components..." 
	@echo "################################################################################"
	$(MAKE) -C tools clean
	rm -f $(REL_PERL_SCRIPTS) $(REL_PERL_MODULES)

# Show help
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  test-file     - Run specific test file (FILE=path/to/test.t)"
	@echo "  install       - Install the application (requires test to pass)"
	@echo "  install-dirs  - Make installation directories"
	@echo "  clean         - Clean up temporary files"
	@echo "  help          - Show this help"
	@echo ""
	@echo "Configuration:"
	@echo "  Edit config.mk to customize installation paths"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  BINDIR=$(BINDIR)"
	@echo "  LIBDIR=$(LIBDIR)"
	@echo "  SHAREDIR=$(SHAREDIR)"
	@echo "  PERL5LIB=$(PERL5LIB)"