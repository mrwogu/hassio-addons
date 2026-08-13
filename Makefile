PYTHON ?= python3

export ADDON
export MESSAGE

.PHONY: bump check validate syntax test

bump:
	@case "$$ADDON" in \
		authentik|bonds|gluetun|n8n|stirling-pdf|traefik_proxy) ;; \
		*) printf '%s\n' "ADDON must be authentik, bonds, gluetun, n8n, stirling-pdf, or traefik_proxy" >&2; exit 2 ;; \
	esac
	@$(PYTHON) scripts/bump_addon_revision.py "$$ADDON" --message "$$MESSAGE"

check: validate syntax test

validate:
	$(PYTHON) scripts/validate_addons.py

syntax:
	@find authentik bonds gluetun n8n stirling-pdf traefik_proxy scripts -type f \( -name '*.sh' -o -name 'addon-entrypoint' \) -print0 | \
		xargs -0 -n1 sh -n

test:
	$(PYTHON) -m unittest discover -s scripts/tests -v
	@set -eu; \
	for test_script in authentik/tests/run.sh bonds/tests/run.sh gluetun/tests/run.sh n8n/tests/run.sh stirling-pdf/tests/run.sh traefik_proxy/tests/run.sh; do \
		echo "Running $$test_script"; \
		sh "$$test_script"; \
	done
