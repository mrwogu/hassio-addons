PYTHON ?= python3

export ADDON
export MESSAGE

.PHONY: bump check validate syntax test integration-traefik

bump:
	@case "$$ADDON" in \
		authentik|bonds|gluetun|n8n|stirling-pdf|traefik-proxy) ;; \
		*) printf '%s\n' "ADDON must be authentik, bonds, gluetun, n8n, stirling-pdf, or traefik-proxy" >&2; exit 2 ;; \
	esac
	@$(PYTHON) scripts/bump_addon_revision.py "$$ADDON" --message "$$MESSAGE"

check: validate syntax test

validate:
	$(PYTHON) scripts/validate_addons.py

syntax:
	@find authentik bonds gluetun n8n stirling-pdf traefik-proxy scripts -type f \( -name '*.sh' -o -name 'addon-entrypoint' \) -print0 | \
		xargs -0 -n1 sh -n

test:
	$(PYTHON) -m unittest discover -s scripts/tests -v
	@set -eu; \
	for test_script in authentik/tests/run.sh bonds/tests/run.sh gluetun/tests/run.sh n8n/tests/run.sh stirling-pdf/tests/run.sh traefik-proxy/tests/run.sh; do \
		echo "Running $$test_script"; \
		sh "$$test_script"; \
	done

integration-traefik:
	@set -eu; \
	for arch in amd64 aarch64; do \
		if [ "$$arch" = aarch64 ]; then platform=linux/arm64; else platform=linux/amd64; fi; \
		image="local/traefik-proxy:3.7.10-$$arch"; \
		docker buildx build --load --platform "$$platform" --tag "$$image" traefik-proxy; \
		ACME_TEST=true ARCH="$$arch" PLATFORM="$$platform" IMAGE="$$image" \
			sh traefik-proxy/tests/integration.sh; \
	done
