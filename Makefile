SHELL := /bin/bash

.PHONY: help init init-repos sync status check gate commands commands-check doctor schemas

help:
	@echo "init          submodules + register the shared specifications store"
	@echo "init-repos    the same, and wire every placeholder under src/"
	@echo "sync          pull the latest shared specifications"
	@echo "status        where every master intent has got to  [INTENT=<id>]"
	@echo "gate          may INTENT=<id> be archived yet?"
	@echo "check         does this checkout satisfy the SDD metric?"
	@echo "commands      regenerate the Qwen commands from the Claude ones"
	@echo "commands-check fail if the Qwen commands are out of sync"
	@echo "schemas       validate the master-intent schema"
	@echo "doctor        sanity-check the OpenSpec root/store relationship"

init:
	./scripts/setup-openspec.sh

init-repos:
	./scripts/setup-openspec.sh --repos

sync:
	./scripts/sync.sh

# Where every master intent has got to, read from the repositories themselves
# rather than from handoff.md's checkboxes. INTENT=<id> narrows it to one.
status:
	./scripts/intent-status.sh $(INTENT)

# The hard gate before archiving a master intent. `openspec archive --yes` only
# warns about an incomplete fan-out; this refuses.
gate:
	@if [ -z "$(INTENT)" ]; then echo "usage: make gate INTENT=<intent-id>"; exit 2; fi
	./scripts/intent-gate.sh $(INTENT)

# Does the current checkout satisfy the "story followed SDD" metric?
# Export JIRA_URL and JIRA_TOKEN to also assert the SDD label against Jira.
check:
	./scripts/check-sdd.sh --all

commands:
	./scripts/gen-qwen-commands.sh

commands-check:
	./scripts/gen-qwen-commands.sh --check

doctor:
	openspec doctor --store specifications

# The schema commands are experimental and do not accept --store, so the schema
# must be validated from inside the root that owns it. `master-intent` is the
# only custom schema in the system: the application repositories deliberately
# use the stock `spec-driven` workflow, so there is nothing to validate there.
schemas:
	@(cd specifications && openspec schema validate master-intent)
