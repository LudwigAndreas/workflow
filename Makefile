SHELL := /bin/bash

REPOS = specifications common backend frontend gitops_backend gitops_frontend nginx

.PHONY: init sync doctor

init:
	git submodule update --init --recursive
	./scripts/setup-openspec.sh

sync:
	./scripts/sync.sh

doctor:
	openspec doctor
