# Common Makefile rules for PSC components

BINPERMS=0755
LIBPERMS=0644

# Pattern rule for Perl scripts: check syntax and install
$(BINDIR)/%: %.pl
	@echo "Installing $< as $@"
	@perl -I . -I $(BASEDIR)src -I $(BASEDIR)webui -c $<
	@cp -v $< $@
	@chmod $(BINPERMS) $@

# Pattern rule for Perl modules
$(LIBDIR)/%.pm: %.pm
	@echo "Installing module $< to $(LIBDIR)/"
	@perl -I $(BASEDIR)src -I $(BASEDIR)webui -c $<
	@mkdir -p $(LIBDIR)/$(dir $<)
	@cp -v $< $(LIBDIR)/$(dir $<)
	@chmod $(LIBPERMS) $@

# Pattern rule for configuration templates (for shared directory installation)
$(SHAREDIR)/config/%: config/%
	@echo "Installing config template $< to $(SHAREDIR)/config/"
	@mkdir -p $(dir $@)
	@cp -rv $< $@ 
