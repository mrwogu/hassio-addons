PYTHON ?= python3
ADDONS := $(shell $(PYTHON) scripts/addon_manifest.py list)

export ADDON
export MESSAGE

.PHONY: bump check validate syntax test badges integration-traefik

bump:
	@if ! printf '%s\n' "$(ADDONS)" | tr ' ' '\n' | grep -Fxq "$$ADDON"; then \
		printf '%s\n' "ADDON must be one of: $(ADDONS)" >&2; \
		exit 2; \
	fi
	@$(PYTHON) scripts/bump_addon_revision.py "$$ADDON" --message "$$MESSAGE"

check: validate syntax test

validate:
	$(PYTHON) scripts/validate_addons.py

syntax:
	@set -eu; \
	addons="$$( $(PYTHON) scripts/addon_manifest.py list )"; \
	find $$addons scripts -type f \( -name '*.sh' -o -name 'addon-entrypoint' \) -print0 | \
		xargs -0 -n1 sh -n

test:
	$(PYTHON) -m unittest discover -s scripts/tests -v
	@set -eu; \
	test_scripts="$$( $(PYTHON) scripts/addon_manifest.py test-scripts )"; \
	printf '%s\n' "$$test_scripts" | while IFS= read -r test_script; do \
		echo "Running $$test_script"; \
		sh "$$test_script"; \
	done

badges:
	$(PYTHON) scripts/generate_addon_badges.py --check

integration-traefik:
	@set -eu; \
	for arch in amd64 aarch64; do \
		if [ "$$arch" = aarch64 ]; then platform=linux/arm64; else platform=linux/amd64; fi; \
		image="local/traefik-proxy:integration-$$arch"; \
		docker buildx build --load --platform "$$platform" --tag "$$image" traefik-proxy; \
		ACME_TEST=true ARCH="$$arch" PLATFORM="$$platform" IMAGE="$$image" \
			sh traefik-proxy/tests/integration.sh; \
	done
