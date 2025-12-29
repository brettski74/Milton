# Makefile for Milton shared configuration components

BASEDIR=../

# Include configuration and rules from parent
-include $(BASEDIR)/config.mk
-include $(BASEDIR)/rules.mk

.PHONY: install install-dirs clean

# Perl modules to install
# Hacky - need better way to do arbitrary depth subdirectories, but this works for now
CONFIG_YAML=$(wildcard *.yaml) $(wildcard */*.yaml) $(wildcard */*/*.yaml)
CONFIG_TEMPLATES=$(wildcard *.yaml.template) $(wildcard */*.yaml.template) $(wildcard */*/*.yaml.template)
CONFIG_FILES=$(CONFIG_YAML) $(CONFIG_TEMPLATES)

CONFIG_DIRS=$(sort $(dir $(CONFIG_FILES)))

REL_CONFIG_DIRS=$(patsubst %,$(SHAREDIR)/config/%,$(CONFIG_DIRS))
REL_CONFIG_FILES=$(patsubst %,$(SHAREDIR)/config/%,$(CONFIG_FILES))

# Create installation directories
install-dirs:
	@echo "Creating release configuration installation directories..."
	@echo "REL_CONFIG_DIRS = $(REL_CONFIG_DIRS)"
	@mkdir -p $(REL_CONFIG_DIRS)

# Install CLI components
install: $(REL_CONFIG_FILES)
	@echo "Release configuration installation complete!"

# Clean up
clean:
	@echo "Cleaning release configuration components..." 
	rm -f $(REL_CONFIG_FILES)

reallyclean: clean
	@echo Removing release configuration installation directories...
	rm -rf $(REL_CONFIG_DIRS)

help:
	@echo "Available targets:"
	@echo "  install       - Install the configuration files"
	@echo "  install-dirs  - Create installation directories"
	@echo "  clean         - Clean up temporary files"
	@echo "  reallyclean   - Clean up temporary files and remove installation directories"
	@echo "  help          - Show this help"
	@echo "Configuration:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  SHAREDIR=$(SHAREDIR)"
	@echo "  CONFIG_DIRS=$(CONFIG_DIRS)"
	@echo "  CONFIG_FILES=$(CONFIG_FILES)"
	@echo "  REL_CONFIG_DIRS=$(REL_CONFIG_DIRS)"
	@echo "  REL_CONFIG_FILES=$(REL_CONFIG_FILES)"