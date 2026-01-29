# Makefile for HP Controller
# Standard Perl project testing and installation setup

BASEDIR=./
# Include configuration and rules
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

TEMPLATE ?= local

TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

VERSION = $(TIMESTAMP)

.PHONY: test test-verbose clean install install-dirs install-config clean-config release tag

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
		$(MAKE) -C $$dir install || exit 1; \
	done
	@echo "Installation complete!"

# Build a release package
release:
	@echo "Building release package for version $(VERSION)"
	@-rm -rf milton-$(VERSION)
	@-rm -rf milton-$(VERSION)-src
	git archive --prefix=milton-$(VERSION)-src/ --format=tar HEAD | tar xv
	mkdir -p milton-$(VERSION) releases
	echo "PREFIX=\$$(BASEDIR)/../milton-$(VERSION)" >milton-$(VERSION)-src/config.mk
	echo "TEMPLATE=release" >>milton-$(VERSION)-src/config.mk
	echo "VERSION=$(VERSION)" >>milton-$(VERSION)-src/config.mk
	echo "BINDIR=\$$(PREFIX)/bin" >>milton-$(VERSION)-src/config.mk
	echo "LIBDIR=\$$(PREFIX)/lib/perl5" >>milton-$(VERSION)-src/config.mk
	echo "SHAREDIR=\$$(PREFIX)/share/milton" >>milton-$(VERSION)-src/config.mk
	echo "PERL5LIB=$(BASEDIR)/src:\$$(PREFIX)/lib/perl5:$(PERL5LIB)" >>milton-$(VERSION)-src/config.mk
	@-rm -rf milton-$(VERSION)-src/resources
	make -C milton-$(VERSION)-src install-dirs install
	echo "$(VERSION)" >milton-$(VERSION)/VERSION
	tar -c milton-$(VERSION)-src | xz -v >releases/milton-$(VERSION)-src.tar.xz
	tar -c milton-$(VERSION) | xz -v >releases/milton-$(VERSION).tar.xz
	@-rm -rf milton-$(VERSION) milton-$(VERSION)-src
	@echo "Release package milton-$(VERSION).tar.xz built successfully"

tag: release
	@echo "Tagging release $(VERSION)"
	git tag -a $(VERSION) -m "Release $(VERSION)"
	git push origin $(VERSION)
	@echo "Tagged release $(VERSION)"

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
	@echo ""
	@echo "  clean         - Clean up temporary files"
	@echo "  help          - Show this help"
	@echo "  install       - Install the application (requires test to pass)"
	@echo "  install-dirs  - Make installation directories"
	@echo "  release       - Build a release tarball"
	@echo "  tag           - Build a release tarball and tag it with a version identifier."
	@echo "  test          - Run all tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  test-file     - Run specific test file (FILE=path/to/test.t)"
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
