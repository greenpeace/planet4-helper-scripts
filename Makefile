SHELL := /bin/bash

HELM_RELEASE ?= $(shell cat HELM_RELEASE)
ifeq ($(strip $(HELM_RELEASE)),)
$(error HELM_RELEASE not set, please run ./configure.sh)
endif
HELM_NAMESPACE ?= $(shell cat HELM_NAMESPACE)
ifeq ($(strip $(HELM_NAMESPACE)),)
$(error HELM_NAMESPACE not set, please run ./configure.sh)
endif
REDIS_SERVICE ?= $(shell cat REDIS_SERVICE)
ifeq ($(strip $(REDIS_SERVICE)),)
$(error REDIS_SERVICE service not set, please run ./configure.sh)
endif

GA_CLIENT_ID ?= $(shell cat GA_CLIENT_ID)
GA_CLIENT_SECRET ?= $(shell cat GA_CLIENT_SECRET)

ifeq ($(strip $(GA_CLIENT_ID)),)
$(error Google Apps Login ClientID not set, please run ./configure.sh)
endif
ifeq ($(strip $(GA_CLIENT_SECRET)),)
$(error Google Apps Login ClientID not set, please run ./configure.sh)
endif

all: nginx-helper ga-login update-links flush-redis

clean:
	rm new.sql
	rm HELM_RELEASE HELM_NAMESPACE REDIS_SERVICE GA_CLIENT_ID GA_CLIENT_SECRET

nginx-helper:
	./update_nginx_helper_redis_servicename.sh $(HELM_RELEASE) $(HELM_NAMESPACE) $(REDIS_SERVICE)

ga-login:
	@echo "./update_ga_login_secrets.sh $(HELM_RELEASE) $(HELM_NAMESPACE) $(REDIS_SERVICE)"
	@GA_CLIENT_ID=$(GA_CLIENT_ID) \
	GA_CLIENT_SECRET=$(GA_CLIENT_SECRET) \
	./update_ga_login_secrets.sh $(HELM_RELEASE) $(HELM_NAMESPACE) $(REDIS_SERVICE)

update-links:
	./update_release_links.sh $(HELM_RELEASE) $(HELM_NAMESPACE) $(REDIS_SERVICE)

flush-redis:
	./flush_release_redis.sh $(HELM_RELEASE) $(HELM_NAMESPACE) 
