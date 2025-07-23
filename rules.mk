# Common Makefile rules for PSC components

BINPERMS=0755
LIBPERMS=0644

# Pattern rule for Perl scripts: check syntax and install
$(BINDIR)/%: %.pl
	@echo "Installing $< as $@"
	@perl -I . -I $(BASEDIR)src -I $(BASEDIR)webui -c $<
	@cp $< $@
	@chmod $(BINPERMS) $@

# Pattern rule for Perl modules
$(LIBDIR)/%.pm: %.pm
	@echo "Installing module $< to $(LIBDIR)/"
	@perl -I $(BASEDIR)src -I $(BASEDIR)webui -c $<
	@mkdir -p $(LIBDIR)/$(dir $<)
	@cp $< $(LIBDIR)/$(dir $<)
	@chmod $(LIBPERMS) $@

# Pattern rule for YAML config files (only if they don't exist)
#$(CONFIGDIR)/%.yaml: %.yaml
#	@if [ -f "$<" ]; then \
#		if [ ! -f "$@" ]; then \
#			echo "Installing config file $<"; \
#			cp $< $@; \
#		else \
#			echo "Config file $< already exists, skipping"; \
#		fi; \
#	fi 