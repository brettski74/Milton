# Makefile for HP Controller
# Standard Perl project testing setup

.PHONY: test test-verbose clean

# Default target
all: test

# Run all tests
test:
	@echo "Running tests..."
	@prove -l t/ HP/t/

# Run tests with verbose output
test-verbose:
	@echo "Running tests with verbose output..."
	@prove -lv t/ HP/t/

# Run specific test file
test-file:
	@if [ -z "$(FILE)" ]; then \
		echo "Usage: make test-file FILE=path/to/test.t"; \
		exit 1; \
	fi
	@prove -lv $(FILE)

# Clean up generated files
clean:
	@echo "Cleaning up..."
	@find . -name "*.tmp" -delete
	@find . -name "*.bak" -delete
	@find . -name "*~" -delete

# Show help
help:
	@echo "Available targets:"
	@echo "  test          - Run all tests"
	@echo "  test-verbose  - Run tests with verbose output"
	@echo "  test-file     - Run specific test file (FILE=path/to/test.t)"
	@echo "  clean         - Clean up temporary files"
	@echo "  help          - Show this help" 