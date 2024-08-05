SPEC_GIT := https://github.com/mustache/spec.git
SPEC_PATH := tests/spec

.PHONY: test
test: $(SPEC_PATH)
	@toit tests/spec-test.toit $(SPEC_PATH)/specs

$(SPEC_PATH):
	@git clone $(SPEC_GIT) $(SPEC_PATH)
