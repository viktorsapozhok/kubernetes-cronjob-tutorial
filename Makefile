MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

JOB ?=
VERSION = 0.1

get_param = yq e .$(1) deployment.yml

aks.namespace := $(shell $(call get_param,aks.namespace))
acr.url := $(shell $(call get_param,acr.url))
jobs := $(shell yq eval '.jobs | keys | join(" ")' deployment.yml)

docker.tag = app
docker.container = app
docker.image = $(acr.url)/$(docker.tag):v$(VERSION)

job.name = $(aks.namespace)-$(subst _,-,$(JOB))
job.schedule = "$(shell $(call get_param,jobs.$(JOB).schedule))"
job.command = $(shell $(call get_param,jobs.$(JOB).command))
job.manifest.template = ./aks-manifest.yml
job.manifest = ./concrete-aks-manifest.yml

.PHONY: help
help:
	@echo 'Tutorial commands:'
	@echo
	@echo 'Usage:'
	@echo '  make deploy       Deploy single job.'
	@echo

.PHONY: _create-manifest
_create-manifest:
	touch $(job.manifest)

	NAME=$(job.name) \
	NAMESPACE=$(aks.namespace) \
	CONTAINER=$(docker.container) \
	IMAGE=$(docker.image) \
	SCHEDULE=$(job.schedule) \
	COMMAND="$(job.command)" \
	envsubst < $(job.manifest.template) > $(job.manifest)

.SILENT: deploy
.PHONY: deploy
deploy:
	make _create-manifest

.SILENT: deploy-all
.PHONY: deploy-all
deploy-all:
	for job in $(JOBS); do \
		$(MAKE) JOB=$$job deploy; \
	done
