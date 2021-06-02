MAKEFLAGS += --no-print-directory
SHELL := /bin/bash

JOB ?=
VERSION = 0.1

get_param = yq e .$(1) deployment.yml

resource_group := $(shell $(call get_param,rg.name))
aks.namespace := $(shell $(call get_param,aks.namespace))
aks.cluster := $(shell $(call get_param,aks.cluster_name))
acr.name := $(shell $(call get_param,acr.name))
acr.url := $(shell $(call get_param,acr.url))

docker.tag = app
docker.container = app
docker.image = $(acr.url)/$(docker.tag):v$(VERSION)

jobs := $(shell yq eval '.jobs | keys | join(" ")' deployment.yml)

job.name = $(aks.namespace)-$(subst _,-,$(JOB))
job.schedule = "$(shell $(call get_param,jobs.$(JOB).schedule))"
job.command = $(shell $(call get_param,jobs.$(JOB).command))
job.agentpool = $(shell $(call get_param,jobs.$(JOB).agentpool))
job.manifest.template = ./aks-manifest.yml
job.manifest = ./concrete-aks-manifest.yml

time.now = $(shell date +"%Y.%m.%d.%H.%M")

.PHONY: help
help:
	@echo 'Usage: make COMMAND [JOB]...'
	@echo
	@echo '  Tutorial commands'
	@echo
	@echo 'Commands:'
	@echo '  build        Build docker image.'
	@echo '  rebuild      Build docker image from scratch.'
	@echo '  push         Push image to docker registry.'
	@echo '  aks-login    Login to Azure Kubernetes Service.'
	@echo '  delete-job   Delete one cron job from AKS.'
	@echo '  delete-all   Delete all jobs from AKS.'
	@echo '  deploy-job   Deploy one cron job to AKS.'
	@echo '  deploy-all   Deploy all jobs to AKS.'
	@echo '  run-job-now  Run one job manually.'

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
	AGENTPOOL=$(job.agentpool) \
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

.PHONY: run-job-now
run-job-now:
	kubectl create job \
	--namespace $(aks.namespace) \
	--from=cronjob/$(job.name) $(job.name)-$(time.now)
