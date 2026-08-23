SHELL := /bin/bash

REPOS = specifications common backend frontend gitops_backend gitops_frontend nginx

.PHONY: help init sync doctor check check-shared version notes

help:
	@echo "init          submodules + register the shared specifications store"
	@echo "sync          pull the latest shared specifications"
	@echo "doctor        sanity-check the OpenSpec root/store relationship"
	@echo "check         does this checkout satisfy the SDD metric?"
	@echo "check-shared  same, against the shared store"
	@echo "version       next version for SERVICE=<name> (run inside an app repo)"
	@echo "notes         release notes for SERVICE=<name>"

init:
	git submodule update --init --recursive
	./scripts/setup-openspec.sh

sync:
	./scripts/sync.sh

doctor:
	openspec doctor

# Does the current checkout satisfy the "story followed SDD" metric?
# See docs/jira-sdd-mapping.md. Export JIRA_URL and JIRA_TOKEN to also
# assert the SDD label and issue type against Jira itself.
check:
	./scripts/check-sdd.sh

# Same, against the shared cross-repo store.
check-shared:
	./scripts/check-sdd.sh --store specifications

# Release helpers. Run these from inside an application repo, pointing at this
# repo's scripts - they read git history, not the workflow repo. See
# docs/release.md.
SERVICE ?= $(notdir $(CURDIR))

version:
	./scripts/release-version.sh --service $(SERVICE)

notes:
	./scripts/release-version.sh --service $(SERVICE) --notes
