.PHONY: help test test-lint test-unit test-e2e lint lint-sh lint-docker clean

help:           ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

test:           ## Run all tests (lint + unit + e2e)
	$(MAKE) test-lint
	$(MAKE) test-unit
	$(MAKE) test-e2e

test-lint:      ## Run static analysis (shellcheck, hadolint, bash -n, JSON validation)
	@echo "=== Static Analysis ==="
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck install.sh uninstall.sh opencode scripts/configure-opencode.sh; \
	else \
		echo "shellcheck not installed, skipping"; \
	fi
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
	else \
		echo "hadolint not installed, skipping"; \
	fi
	@echo "bash -n syntax check..."
	bash -n install.sh
	bash -n uninstall.sh
	bash -n opencode
	bash -n scripts/configure-opencode.sh
	@echo "JSON validation..."
	jq empty preconfig/opencode.json
	@echo "Frontmatter validation..."
	@for f in preconfig/agents/*.md; do \
		head -1 "$$f" | grep -q '^---$$' || { echo "FAIL: $$f missing opening ---"; exit 1; }; \
		sed -n '2,/^---$$/{ /^---$$/d; p; }' "$$f" | grep -q 'description:' || { echo "FAIL: $$f missing description"; exit 1; }; \
		sed -n '2,/^---$$/{ /^---$$/d; p; }' "$$f" | grep -q 'mode:' || { echo "FAIL: $$f missing mode"; exit 1; }; \
		sed -n '2,/^---$$/{ /^---$$/d; p; }' "$$f" | grep -q 'temperature:' || { echo "FAIL: $$f missing temperature"; exit 1; }; \
		sed -n '2,/^---$$/{ /^---$$/d; p; }' "$$f" | grep -q 'permission:' || { echo "FAIL: $$f missing permission"; exit 1; }; \
		echo "  OK: $$f"; \
	done
	@echo "All lint checks passed."

test-unit:      ## Run unit tests with bats
	@echo "=== Unit Tests ==="
	@if command -v bats >/dev/null 2>&1; then \
		bats test/test_configure.bats test/test_wrapper.bats test/test_install_flags.bats; \
	else \
		echo "bats not installed. Install with: npm install -g bats"; \
		exit 1; \
	fi

test-e2e:       ## Run end-to-end tests (requires Docker)
	@echo "=== End-to-End Tests ==="
	@if command -v docker >/dev/null 2>&1; then \
		bats test/test_e2e.bats; \
	else \
		echo "Docker not available, skipping E2E tests"; \
	fi

lint: test-lint

lint-sh:        ## Run shellcheck on all shell scripts
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck install.sh uninstall.sh opencode scripts/configure-opencode.sh; \
	else \
		echo "shellcheck not installed. Install with: apt install shellcheck"; \
		exit 1; \
	fi

lint-docker:    ## Run hadolint on Dockerfile
	@if command -v hadolint >/dev/null 2>&1; then \
		hadolint Dockerfile; \
	else \
		docker run --rm -i hadolint/hadolint < Dockerfile; \
	fi

clean:          ## Clean up test artifacts
	-docker rmi test-minimal:latest test-recommended:latest 2>/dev/null || true
