SHELL := /bin/bash

RELEASE := $(shell cat HELM_RELEASE)
ifeq ($(strip $(RELEASE)),)
$(error Release not set, please run ./configure.sh)
endif
NAMESPACE := $(shell cat HELM_NAMESPACE)
ifeq ($(strip $(NAMESPACE)),)
$(error Namespace not set, please run ./configure.sh)
endif
REDIS := $(shell cat REDIS_SERVICE)
ifeq ($(strip $(REDIS)),)
$(error Redis service not set, please run ./configure.sh)
endif

GA_CLIENT_ID ?= $(shell cat GA_CLIENT_ID)
GA_CLIENT_SECRET ?= $(shell cat GA_CLIENT_SECRET)

ifeq ($(strip $(GA_CLIENT_ID)),)
$(error Google Apps Login ClientID not set, please run ./configure.sh)
endif
ifeq ($(strip $(GA_CLIENT_SECRET)),)
$(error Google Apps Login ClientID not set, please run ./configure.sh)
endif

all: nginx-helper ga-login release-links

clean:
	rm new.sql
	rm HELM_RELEASE HELM_NAMESPACE REDIS_SERVICE GA_CLIENT_ID GA_CLIENT_SECRET

nginx-helper:
	./update_nginx_helper_redis_servicename.sh $(RELEASE) $(NAMESPACE) $(REDIS)

ga-login:
	@echo "./update_ga_login_secrets.sh $(RELEASE) $(NAMESPACE) $(REDIS)"
	@GA_CLIENT_ID=$(GA_CLIENT_ID) \
	GA_CLIENT_SECRET=$(GA_CLIENT_SECRET) \
	./update_ga_login_secrets.sh $(RELEASE) $(NAMESPACE) $(REDIS)

release-links:
	./update_release_links.sh $(RELEASE) $(NAMESPACE) $(REDIS)
