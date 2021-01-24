MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash

JOB ?=

get_param = yq e .$(1) deployment.yml

JOBS := $(shell yq eval '.jobs | keys | join(", ")' deployment.yml)

SCHEDULE := $(shell $(call get_param,jobs.$(JOB).schedule))
COMMAND := $(shell $(call get_param,jobs.$(JOB).command))

NAMESPACE := $(shell $(call get_param,aks.namespace))
KUBE = kubectl --namespace $(NAMESPACE)

.PHONY: help
help:
	@echo 'Tutorial commands:'
	@echo
	@echo 'Usage:'
	@echo '  make test         Test command.'
	@echo

.SILENT: test
.PHONY: test
test:
	echo "$(SCHEDULE)"
	echo $(COMMAND)
	echo $(JOBS)

.PHONY: get-pods
get-pods:
	$(KUBE) get pods