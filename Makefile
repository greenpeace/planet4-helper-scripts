SHELL := /bin/bash

.EXPORT_ALL_VARIABLES:

HELM_RELEASE ?= $(shell cat HELM_RELEASE 2>/dev/null)
HELM_NAMESPACE ?= $(shell cat HELM_NAMESPACE 2>/dev/null)
REDIS_SERVICE ?= $(shell cat REDIS_SERVICE 2>/dev/null)

GA_CLIENT_ID ?= $(shell cat GA_CLIENT_ID 2>/dev/null)
GA_CLIENT_SECRET ?= $(shell cat GA_CLIENT_SECRET 2>/dev/null)

all: ga-login update-links flush-redis

lint: lint-sh

lint-sh:
	find . -type f -name '*.sh' | xargs shellcheck

clean:
	rm new.sql
	rm HELM_RELEASE HELM_NAMESPACE REDIS_SERVICE GA_CLIENT_ID GA_CLIENT_SECRET

check-all-vars: check-helm-vars check-oauth-vars

check-oauth-vars:
	@test -n "$(GA_CLIENT_ID)" # $$GA_CLIENT_ID
	@test -n "$(GA_CLIENT_SECRET)" # $$GA_CLIENT_SECRET
	@echo "Oauth Client ID: $(GA_CLIENT_ID)"

check-helm-vars:
	@test -n "$(HELM_RELEASE)" # $$HELM_RELEASE
	@test -n "$(HELM_NAMESPACE)" # $$HELM_NAMESPACE
	@echo "Release:   $(HELM_RELEASE)"
	@echo "Namespace: $(HELM_NAMESPACE)"

ga-login: check-all-vars
	./update_ga_login_secrets.sh

update-links: check-helm-vars
	./update_release_links.sh

flush-redis:
	@test -n "$(REDIS_SERVICE)" # $$REDIS_SERVICE
	./flush_release_redis.sh
