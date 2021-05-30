MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

JOB ?=
VERSION = 0.1

get_param = yq e .$(1) deployment.yml

resource_group := $(shell $(call get_param,rg.name))
aks.namespace := $(shell $(call get_param,aks.namespace))
aks.cluster := $(shell $(call get_param,aks.cluster_name))
acr.url := $(shell $(call get_param,acr.url))

docker.tag = app
docker.container = app
docker.image = $(acr.url)/$(docker.tag):v$(VERSION)

jobs := $(shell yq eval '.jobs | keys | join(" ")' deployment.yml)

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

.PHONY: build
build:
	docker build --tag $(docker.image) .

.PHONY: rebuild
rebuild:
	docker build --no-cache --tag $(docker.image) .

.PHONY: push
push:
	az acr login --name $(acr.name)
	docker push $(docker.image)

.SILENT: _create-manifest
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

.PHONY: aks-login
aks-login:
	az aks get-credentials --resource-group $(resource_group) --name $(aks.cluster)

# Delete cronjob, (`-` means to continue on error)
.SILENT: delete-job
.PHONY: delete-job
delete-job:
	-kubectl --namespace $(aks.namespace) delete cronjob $(job.name)

.SILENT: delete-all
.PHONY: delete-all
delete-all:
	for job in $(jobs); do \
		echo "removing $$job"; \
		$(MAKE) JOB=$$job delete-job; \
		echo ""; \
	done

.SILENT: deploy-job
.PHONY: deploy-job
deploy-job:
	make delete-job
	make _create-manifest
	kubectl apply -f $(job.manifest)
	rm $(job.manifest)

.SILENT: deploy-all
.PHONY: deploy-all
deploy-all:
	for job in $(jobs); do \
		echo "deploying $$job"; \
		$(MAKE) JOB=$$job deploy-job; \
		echo ""; \
	done
