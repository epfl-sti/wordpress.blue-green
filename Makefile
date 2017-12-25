###################################################################
# Constants
###################################################################
SITE_NAME := sti-test.epfl.ch
WEB_GROUP := www-data

###################################################################
# Default target (overridable on the command line)
###################################################################

# User is free to bypass the auto-detection of the target like this:
#   make whatever TARGET=blue
ifdef TARGET
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

include jahia2wp_$(MASTER)/.env

.PHONY: _debug
_debug:
	@echo MASTER=$(MASTER)
	@echo STANDBY=$(STANDBY)

###################################################################
# Targets that care about which instance is master / standby
###################################################################

BACKUPFILE = /srv/sti.epfl.ch/backup/$(TARGET)/backup-$(shell date +%Y%m%d-%H:%m:%S).tgz

.PHONY: backup-mgmt
backup-mgmt:
	$(in-docker-mgmt) bash -c "rm -rf /srv/backup; mkdir /srv/backup"
# We'll be needing this until
# https://github.com/epfl-idevelop/jahia2wp/pull/173 hits Docker hub:
	@$(call apt-install,mgmt,php7.0-xml)
	$(master-wp) export --stdout > jahia2wp_$(MASTER)/volumes/srv/backup/wordpress.xml
# Save backup size by only backing up original images; we'll regenerate the others.
	$(in-docker-mgmt) bash -c "cd $(docker-htdocs);                 \
	    find wp-content/uploads -not \(                             \
	         -type f                                                \
	         -iregex '.*-[0-9]+x[0-9]+\.\(png\|gif\|jpg\|jpeg\)'    \
	    \) -print0                                                  \
	    > /srv/backup/uploads_manifest"
	@$(call apt-install,mgmt,rsync)
	$(in-docker-mgmt) bash -c "cd $(docker-htdocs);                 \
	  rsync -0av --files-from /srv/backup/uploads_manifest          \
	  . /srv/backup/"

.PHONY: _whatever
_whatever:
	$(master-wp) export --help


###################################################################
# Global targets (apply to both instances)
###################################################################

.PHONY: perms
perms:
	$(call in-docker-httpd,blue)  chgrp -R www-data $(call docker-htdocs,blue)
	$(call in-docker-httpd,blue)  chmod -R g+wsX    $(call docker-htdocs,blue)
	$(call in-docker-httpd,green) chgrp -R www-data $(call docker-htdocs,green)
	$(call in-docker-httpd,green) chmod -R g+wsX    $(call docker-htdocs,green)

###################################################################
# Library code
###################################################################

# All variables assigned with "=" are lazily evaluated.

# Usage: $(call docker-id,mgmt) or $(call docker-id,mgmt,blue)
docker-id = jahia2wp$(if $(2),$(2),$(MASTER))_$(1)_1

# Usage: $(in-docker-mgmt) bash -c whatever
# or     $(call in-docker-mgmt,blue) bash -c whatever
in-docker-mgmt = docker exec --user=www-data $(call docker-id,mgmt,$(1))

# Usage: $(in-docker-httpd) bash -c whatever
# or     $(call in-docker-httpd,blue) bash -c whatever
in-docker-httpd = docker exec $(call docker-id,httpd,$(1))

master-wp = $(in-docker-mgmt) wp --path=/srv/$(WP_ENV)/$(SITE_NAME)/htdocs/

# Usage: @$(call apt-install,mgmt,php7.0-xml)
apt-install = docker exec $(call docker-id,$(1)) apt -y install $(2) >/dev/null 2>&1

# Usage: $(docker-htdocs)
# or     $(call docker-htdocs,blue)
docker-htdocs = /srv/$(if $(1),$(1),$(WP_ENV))/$(SITE_NAME)/htdocs
