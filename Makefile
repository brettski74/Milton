# Makefile for HP Controller
# Standard Perl project testing and installation setup

BASEDIR=./
# Include configuration and rules
-include $(BASEDIR)config.mk
-include $(BASEDIR)rules.mk

.PHONY: test test-verbose clean install install-dirs

TEST_DIRS=$(shell find . -type d -name t)

SUBDIRS=src webui

# Configuration files to install
CONFIG_FILES=command controller interface device *.yaml

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
	@mkdir -p $(CONFIGDIR)

# Install configuration files
install-config: $(CONFIGDIR)/command $(CONFIGDIR)/controller $(CONFIGDIR)/interface $(CONFIGDIR)/device \
               $(CONFIGDIR)/psc.yaml $(CONFIGDIR)/delaycal.yaml $(CONFIGDIR)/controller-udp6721-calibration.yaml $(CONFIGDIR)/power_supply_calibration.yaml
	@echo "Configuration installation complete!"

# Main install target
install:
	@for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir install; \
	done
	@echo "Installation complete!"

# Clean up generated files
clean:
	@echo "Cleaning up..."
	@$(MAKE) -C src clean
	@$(MAKE) -C webui clean

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
	@echo "  CONFIG_PREFIX=$(CONFIG_PREFIX)"
	@echo "  BINDIR=$(BINDIR)"
	@echo "  LIBDIR=$(LIBDIR)"
	@echo "  CONFIGDIR=$(CONFIGDIR)" 
