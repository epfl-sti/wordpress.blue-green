.PHONY: backup backup-in-docker

# User is free to bypass the auto-detection of the target like this:
#   make whatever TARGET=blue
ifneq '' '$(TARGET)'
MASTER := $(TARGET)
STANDBY := $(TARGET)
else
MASTER := $(shell cat lb/MASTER)
ifeq ($(MASTER), green)
	STANDBY := blue
else
	STANDBY := green
endif
endif

JAHIA2WP = jahia2wp_$(MASTER)
include $(JAHIA2WP)/.env

debug:
	echo MASTER=$(MASTER) STANDBY=$(STANDBY)

# All variables assigned with "=" are lazily evaluated.
master_mgmt_docker_id = $(shell docker ps -q --filter "label=ch.epfl.jahia2wp.mgmt.env=$(MASTER)")
master_mgmt_docker_exec_args = --user=www-data $(master_mgmt_docker_id)
master_mgmt_docker_exec = docker exec $(master_mgmt_docker_exec_args)
master_wp = $(master_mgmt_docker_exec) wp --path=/srv/$(WP_ENV)/sti-test.epfl.ch/htdocs/

# We'll be needing this until
# https://github.com/epfl-idevelop/jahia2wp/pull/173 hits Docker hub:
master_mgmt_update = docker exec $(master_mgmt_docker_id) apt -y install php7.0-xml >/dev/null 2>&1

BACKUPFILE = /srv/sti.epfl.ch/backup/$(TARGET)/backup-$(shell date +%Y%m%d-%H:%m:%S).tgz

backup-in-docker:
	@$(master_mgmt_update)
	$(master_mgmt_docker_exec) bash -c "rm -rf /srv/backup; mkdir /srv/backup"
	$(master_wp) export --dir=/srv/backup

