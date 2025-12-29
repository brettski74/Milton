# Makefile for HP Controller
# Standard Perl project testing and installation setup

BASEDIR=./
# Include configuration and rules
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

TEMPLATE ?= local

.PHONY: test test-verbose clean install install-dirs install-config clean-config

TEST_DIRS=$(shell find . -type d -name t)

SUBDIRS=src webui config

# Default target
all: test

# Run all tests
test:
	@for dir in $(SUBDIRS); do \
		echo "Running tests in $$dir..."; \
		$(MAKE) -C $$dir test; \
	done

# Run tests with verbose output
test-verbose:
	@for dir in $(SUBDIRS); do \
		echo "Running tests in $$dir..."; \
		$(MAKE) -C $$dir test-verbose; \
	done

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test.t"; \
		exit 1; \
	fi
	@prove -lv $(FILE)

# Create installation directories
install-dirs:
	@echo "Creating installation directories..."
	@mkdir -p $(BINDIR)
	@mkdir -p $(LIBDIR)
	@mkdir -p $(SHAREDIR)
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir install-dirs; \
	done

# Main install target
install:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir install; \
	done
	@echo "Installation complete!"

# Clean up generated files
clean:
	@echo "Cleaning up..."
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done

config.mk: config.mk.$(TEMPLATE)
	@cp -n config.mk.$(TEMPLATE) config.mk
	@touch config.mk

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

reallyclean: clean
	rm -rf $(HOME)/.config/milton $(HOME)/.local/milton
