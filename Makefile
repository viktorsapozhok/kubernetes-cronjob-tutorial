MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

JOB ?=

get_param = yq e .$(1) deployment.yml

JOBS := $(shell yq eval '.jobs | keys | join(" ")' deployment.yml)

.PHONY: help
help:
	@echo 'Tutorial commands:'
	@echo
	@echo 'Usage:'
	@echo '  make deploy       Deploy single job.'
	@echo

.SILENT: deploy
.PHONY: deploy
deploy:
	$(eval SCHEDULE := $(shell $(call get_param,jobs.$(JOB).schedule)))
	$(eval COMMAND := $(shell $(call get_param,jobs.$(JOB).command)))

	echo deploying $(JOB)
	echo schedule: "$(SCHEDULE)"
	echo command: "$(COMMAND)"

.SILENT: deploy-all
.PHONY: deploy-all
deploy-all:
	for job in $(JOBS); do \
		$(MAKE) JOB=$$job deploy; \
		echo ""; \
	done
