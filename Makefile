## Project Metadata
PROJECT_NAME ?= cloud-stack
AWS_ACCOUNT_ID ?= 556085509259
AWS_REGION ?= us-east-1
IMAGE_REPO_NAME ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PROJECT_NAME)
AWS_ARTIFACTS_S3_BUCKET ?= s3://artifacts.int.build.briggo.io/$(PROJECT_NAME)

.PHONY: default
default:
	@echo "------------- $(PROJECT_NAME) Makefile Quick Start --------------"
	@echo "usage                  : Full listing of target descriptions"
	@echo "clean-all              : Resets directory, removes running containers, and removes generated .env file."
	@echo "clean                  : Remove auto-generated files."
	@echo "docker-build           : Cleans, tags, and builds all docker containers."
	@echo "docker-build.<dir>     : Cleans, tags, and builds the docker container <dir>."
	@echo "docker-push            : Cleans, tags, builds, pushes all docker containers."
	@echo "docker-push.<dir>      : Cleans, tags, builds, and pushes the docker container <dir>."

.PHONY: usage
usage: ## Prints description of each target
	@grep -E '^[a-zA-Z_-]+.*:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":|##"}; {printf "  \033[36m%-15s\033[0m %s. Depends on [%s]\n", $$2, $$4, $$3}'

DOLLAR := $$
SLASH := /
DOT_SLASH := ./
PWD:=$(shell pwd)
UNDERSCORE:=_
EMPTY:=
SPACE:=$(EMPTY) $(EMPTY)
QUOTE:=
DOUBLE_QUOTE:="

BRANCH := $(shell git rev-parse --abbrev-ref HEAD | sed s%$(SLASH)%-%g)
DATE := $(shell date +%Y%m%d)
TIME := $(shell date +'%H%M%S')
DATETIME := $(DATE)-$(TIME)
TIMESTAMP := $(shell date +%s)

ENV_FILE := .env
DOCKER_PARENT_DIR_NAME :=
DOCKER_DIR := $(PWD)$(SLASH)
DOCKER_DIR_REL := $(DOT_SLASH)$(DOCKER_PARENT_DIR_NAME)

BUILD_DIR_NAME := build
BUILD_DIR := $(PWD)$(SLASH)$(BUILD_DIR_NAME)
BUILD_DIR_REL := $(DOT_SLASH)$(BUILD_DIR_NAME)

NO_COLOR=\x1b[0m
OK_COLOR=\x1b[37;10m
WHITE=\x1b[32;01m
ERROR_COLOR=\x1b[31;01m
WARN_COLOR=\x1b[33;01m
INFO_COLOR=\x1b[35;10m
INFO2_COLOR=\x1b[31;10m
OK_STRING=$(OK_COLOR)[OK]$(NO_COLOR)
ERROR_STRING=$(ERROR_COLOR)[ERRORS]$(NO_COLOR)
WARN_STRING=$(WARN_COLOR)[WARNINGS]$(NO_COLOR)


################################################################################
## House Keeping and Prerequisites Check
################################################################################

check_defined ?= \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))

__check_defined ?= \
    $(if $(value $1),, \
        $(error Undefined $1$(if $2, ($2))$(if $(value @), \
                required by target `$@')))

check-defined-%: __check_defined_FORCE
    @:$(call check_defined, $*, target-specific)

.PHONY: __check_defined_FORCE
__check_defined_FORCE:
	@:$(call check_defined, FORCE_IT, target-specific)

.PHONY: aws-login
aws-login: ## Generates AWS ECR Login script
	@echo $(shell aws ecr get-login --no-include-email --region us-east-1 --registry-ids $(AWS_ACCOUNT_ID) | sh)


$(ENV_FILE): ## Generates the development version of the "$(ENV_FILE)" file
	@$(shell rm .env 2>/dev/null || true)
	$(eval FILTER := environment% default automatic)
	$(eval FILTER2 := check_defined __check_defined .DEFAULT_GOAL)
	@$(foreach V,$(sort $(.VARIABLES)), \
		$(if \
			$(filter-out $(FILTER),$(origin $V)), \
				$(if \
					$(filter-out $(FILTER2),$V), \
    					$(eval I=$(subst $(DOUBLE_QUOTE),$(UNDERSCORE),$($V))) \
						$(eval J:=$(subst $(SPACE),$(UNDERSCORE),$($I))) \
						$(eval K:=$V=$($V)) \
						$(shell printf "$K\n" >> $(ENV_FILE)) \
				) \
		) \
	)
	@echo "$(OK_COLOR)$@.................................[DONE]$(NO_COLOR)"


################################################################################
## Docker Prereqs
################################################################################
DOCKER_VERSION := $(shell docker --version 2>/dev/null)
DOCKER_COMPOSE_VERSION := $(shell docker-compose --version 2>/dev/null)
AWSCLI_VERSION := $(shell aws --version 2>/dev/null)
AWSCLI_CP := aws s3 cp
AWS_WHOAMI := $(word 2,$(shell aws opsworks --output text --region us-east-1 describe-my-user-profile 2>/dev/null))
AWS_AUTH_SUCCESS_TOKEN := arn:aws:iam::$(AWS_ACCOUNT_ID)

.PHONY: prereqs-docker
prereqs-docker: ## Tests to see if the required dependencies are installed
ifeq ($(strip $(DOCKER_VERSION)),)
	@echo "Docker not installed"
	@$(eval EXIT=1)
endif
ifeq ($(strip $(DOCKER_COMPOSE_VERSION)),)
	@echo "Docker Compose not installed"
	@$(eval EXIT=1)
endif
ifeq ($(strip $(AWSCLI_VERSION)),)
	@echo "AWS CLI not installed"
	@$(eval EXIT=1)
endif
ifeq ($(findstring $(AWS_AUTH_SUCCESS_TOKEN),$(AWS_WHOAMI)),)
	@echo "AWS User Credentials do not appear to be working."
	@echo "  Have you run 'aws configure'?"
	@echo "  Should you have AWS_PROFILE set?"
	@$(eval EXIT=1)
endif
ifeq ($(strip $(EXIT)),1)
	$(error "Exiting")
endif
	@echo "$(DOCKER_VERSION)"
	@echo "$(DOCKER_COMPOSE_VERSION)"
	@echo "$(AWSCLI_VERSION)"
	@echo "Logged in as: $(AWS_WHOAMI)"
	@echo ""

################################################################################
## Docker Container Operations
################################################################################
CONTAINER_DIRS = $(sort $(dir $(wildcard $(DOCKER_DIR_REL)$(SLASH)*$(SLASH))))
CONTAINERS_NEXT = $(foreach CONTAINER,$(CONTAINER_DIRS),$(filter-out $(DOCKER_DIR_REL),$(subst $(DOCKER_DIR_REL)$(SLASH),,$(subst $(SLASH)$(SLASH),,$(CONTAINER)$(SLASH)))))
CONTAINERS = $(foreach CONTAINER,$(CONTAINERS_NEXT),$(subst .,,$(CONTAINER)))

## Docker Container Versions used for Tagging
RABBITMQ_TAG:=:$(DATETIME)
POSTGRES_BACKUP_TAG:=:$(DATETIME)
POSTGRES_TAG:=:$(DATETIME)
NGINX_TAG:=:$(DATETIME)
LOGSPOUT_TAG:=:$(DATETIME)
CONSUL_TAG:=:$(DATETIME)
VAULT_TAG:=:$(DATETIME)
TLS_GEN_TAG:=:$(DATETIME)
REGISTRATOR_TAG:=:$(DATETIME)

.PHONY: containers
containers: ## Prints the list of Docker containers that will be built, published, etc by this Makefile
	@echo "Available Docker Containers"
	@echo $(CONTAINERS)

%.container:
	@echo ""
	$(eval CONTAINER:=$*)
	$(eval CONTAINER_TAG:=$($(shell echo $(CONTAINER) | tr a-z A-Z | tr - _)_TAG))
	@echo "$(INFO_COLOR)Processing [$(CONTAINER)]$(NO_COLOR)"
	$(eval IMAGE:=$(IMAGE_REPO_NAME)$(SLASH)$(CONTAINER)$(CONTAINER_TAG))
	@echo "--> tag:[$(IMAGE)]"

.PHONY: docker-build
docker-build: $(foreach CONTAINER, $(CONTAINERS) , docker-build.$(CONTAINER))  ## Builds each container under the directory $(DOCKER_DIR)

docker-build.%: $(ENV_FILE) prereqs-docker %.container  ## Builds a specific container via wildcard ie "build.postgres"
	@cd $(DOCKER_DIR_REL)$(CONTAINER); \
	pwd | xargs printf "\--> work dir:[%s]\n"; \
	echo "Building and tagging $(IMAGE)"; \
	./prepare.sh || true; \
	$(eval BUILD_ARGS := `cat build.env | sed 's/\(.*\)/--build-arg \1/g' | tr '\n' ' '`) \
	$(eval export @$(shell cat $(PWD)/$(ENV_FILE))) \
	docker build $(BUILD_ARGS) -t ${IMAGE} . || true
	@echo "$(OK_COLOR)$@.................................[DONE]$(NO_COLOR)"

.PHONY: docker-push
docker-push: $(foreach CONTAINER,$(CONTAINERS),docker-push.$(CONTAINER)) ## Pushes each container under the directory $(DOCKER_DIR)

docker-push.%: prereqs-docker aws-login docker-build.% ## Pushes a specific container via wildcard ie "push.postgres"
	@cd $(DOCKER_DIR_REL)$(SLASH)$(CONTAINER); \
	pwd | xargs printf '  dir:[%s]\n'; \
	mkdir -p ${BUILD_DIR_REL}; \
	echo "Pushing $(IMAGE)"; \
	docker push $(IMAGE) | sed  's/^.*\(sha.*\)[\s].*$$/@\1/w ${BUILD_DIR_REL}${SLASH}digest' && \
	while read line; do \
	echo "DIGEST=$$line" > ${BUILD_DIR_REL}${SLASH}manifest && \
	echo "TAG=${STAMP}" >> ${BUILD_DIR_REL}${SLASH}manifest && \
	echo "VERSION=${VERSION}" >> ${BUILD_DIR_REL}${SLASH}manifest && \
	echo "DATE=${DATETIME}" >> ${BUILD_DIR_REL}${SLASH}manifest && \
	echo "GIT_BRANCH=$(BRANCH)" >> ${BUILD_DIR_REL}${SLASH}manifest; \
	done < ${BUILD_DIR_REL}${SLASH}digest && \
	grep -q sha256 digest && \
	rm ${BUILD_DIR_REL}${SLASH}digest || true;
	@echo "$(OK_COLOR)$@.................................[DONE]$(NO_COLOR)"

.PHONY: docker-run
docker-run:
	@echo "Which docker container? Options are:"
	@echo $(CONTAINERS) | xargs printf '  make run\.%s\n'
	@echo ""
	@docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
	@exit 1

docker-run.%: docker-build.% ## Runs a specific container via wildcard ie "stop.postgres".  The container must have its spec under the $(DOCKER_DIR) directory
	@cd $(DOCKER_DIR_REL)$(SLASH)$(CONTAINER); \
	pwd | xargs printf '  dir:[%s]\n'; \
	echo "Starting docker container name ${CONTAINER}"; \
	docker run -d ${DEV_RUN_ARGS} --name ${CONTAINER} ${IMAGE};

.PHONY: docker-ps
docker-ps: ## List out all running docker services
	@docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"

.PHONY: docker-terminal
docker-terminal:
	@echo "Which docker instance? Options are:"
	@docker ps --format "{{.Names}}" | xargs printf '  make terminal\.%s\n'
	@exit 1

docker-terminal.%: %.container ## Access to shell terminal of one of the running docker servcies specified via wildcard ie "terminal.postgres"
	$(eval CONTAINER_INSTANCE := `docker ps --format "{{.ID}};{{.Names}}" | grep $(CONTAINER)`)
	@echo "Interactive Terminal [$(shell echo "$(CONTAINER_INSTANCE)" | cut -d ";" -f 1)] [$(shell echo "$(CONTAINER_INSTANCE)" | cut -d ";" -f 2)]"
	docker exec -it $(shell echo "$(CONTAINER_INSTANCE)" | cut -d ";" -f 1) sh

.PHONY: docker-logs
docker-logs:
	@echo "Which docker instance to you want to follow? Options are:"
	@docker ps --format "{{.Names}}" | xargs printf '  make logs\.%s\n'
	@exit 1

docker-logs.%: %.container ## Tail the log output of one of the running docker servcies specified via wildcard ie "logs.postgres"
	$(eval CONTAINER_INSTANCE := `docker ps --format "{{.ID}};{{.Names}}" | grep $(CONTAINER)`)
	@echo "Following Logs [$(shell echo "$(CONTAINER_INSTANCE)" | cut -d ";" -f 1)] [$(shell echo "$(CONTAINER_INSTANCE)" | cut -d ";" -f 2)]"
	docker logs -f $(shell echo "$(CONTAINER_INSTANCE)" | cut -d ";" -f 1)

.PHONY: docker-stop-all
docker-stop-all: $(foreach CONTAINER,$(CONTAINERS),docker-stop.$(CONTAINER)) ## Stops all running docker containers named under directory $(DOCKER_DIR)

docker-stop.%: %.container ## Stops a specific container via wildcard ie "stop.postgres"
	@cd $(DOCKER_DIR_REL)$(SLASH)$(CONTAINER); \
	pwd | xargs printf '  dir:[%s]\n'; \
	echo "Stopping docker container name ${CONTAINER}"; \
	docker stop ${CONTAINER} 2>/dev/null || true;

.PHONY: docker-stop
docker-stop:
	@echo "Which docker instance? Options are:"
	@docker ps --format "{{.Names}}" | xargs printf '  make stop\.%s\n'
	@exit 1

.PHONY: docker-rm-all
docker-rm-all: $(foreach CONTAINER,$(CONTAINERS),docker-rm.$(CONTAINER)) ## Removes all stopped and running docker containers named under directory $(DOCKER_DIR)

docker-rm.%: docker-stop.%  ## Removes and stops a specific container via wildcard ie "rm.postgres"
	@cd $(DOCKER_DIR_REL)$(SLASH)$(CONTAINER); \
	pwd | xargs printf '  dir:[%s]\n'; \
	rm ${BUILD_DIR_REL}${SLASH}* 2>/dev/null || true; \
	docker rm ${CONTAINER} 2>/dev/null || true;

.PHONY: docker-rm
docker-rm:
	@echo "Which docker instance? Options are:"
	@docker ps --format "{{.Names}}" | xargs printf '  make rm\.%s\n'
	@exit 1

