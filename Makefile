###################################################################
# Master Makefile for the sti{,-test}.epfl.ch blue/green deployment
###################################################################

.PHONY: help
_v:=@echo >&2
help:
	$(_v) "Unless specifically told otherwise, the following targets read from the master"
	$(_v) "instance (as determined by the contents of the lb/MASTER file) and write to"
	$(_v) "the standby instance:"
	$(_v) ""
	$(_v) "        make backup"
	$(_v) "        make restore"
	$(_v) "        make backup restore FLAGS=--mirror"
	$(_v) "        make gitpull"
	$(_v) ""
	$(_v) "The following commands act on both instances:"
	$(_v) ""
	$(_v) "        make perms"
	$(_v) ""
	$(_v) "Read the Makefile for more (look for .PHONY rules)"


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

.PHONY: backup-mgmt
backup-mgmt:
	$(in-docker-mgmt) bash -c "rm -rf /srv/backup; mkdir /srv/backup"
# We'll be needing this until
# https://github.com/epfl-idevelop/jahia2wp/pull/173 hits Docker hub:
	@$(call apt-install,mgmt,php7.0-xml)
	$(master-wp) export --stdout > $(srv-backup-path-outside)/wordpress.xml
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

.PHONY: backup-db
backup-db:
	$(call mysqldump,$(dbname)) \
	  | perl -pe 'if (! $$done && s|Host: localhost|host: db-$(MASTER)|g) { $$done++; }' \
	  > $(srv-backup-path-outside)/dump-wp.sql
# dump-all.sql is just for belt+suspenders
	$(call mysqldump,--all-databases) \
+	  > $(srv-backup-path-outside)/dump-all.sql

BACKUPFILE = /srv/sti.epfl.ch/backup/$(MASTER)/backup-$(shell date +%Y%m%d-%H:%M:%S).tgz
.PHONY: backup
backup: backup-mgmt backup-db
	cp -a scripts/restore.sh $(srv-backup-path-outside)/
	cd $(srv-backup-path-outside); tar zcf $(BACKUPFILE) *
	ln -sf $(shell basename $(BACKUPFILE)) /srv/sti.epfl.ch/backup/$(MASTER)/latest.tgz

.PHONY: restore
restore:
	@-docker exec -it $(call docker-id,mgmt,$(STANDBY)) rm -rf /tmp/restore
# The "wp media regenerate" command needs GD:
	@$(call apt-install,mgmt,php7.0-gd,$(STANDBY))
	$(call in-docker-mgmt,$(STANDBY)) mkdir /tmp/restore
	docker cp -L /srv/sti.epfl.ch/backup/$(MASTER)/latest.tgz $(call docker-id,mgmt,$(STANDBY)):/tmp/restore/
	$(call in-docker-mgmt,$(STANDBY)) tar -C/tmp/restore -zxvf /tmp/restore/latest.tgz restore.sh
	$(call in-docker-mgmt,$(STANDBY)) /tmp/restore/restore.sh $(FLAGS)

.PHONY: gitpull
gitpull:
	@-find "jahia2wp_$(STANDBY)"/htdocs/wp-content/ -name .git -print0| \
	    xargs -0 -i bash -c 'set -e -x; cd "$$(dirname {})"; git branch; git pull --ff-only'
	cd "jahia2wp_$(STANDBY)"/htdocs/wp-content/themes/epfl-sti; su -s /bin/bash www-data -c 'npm i'

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

# Usage: $(in-docker-db) bash -c whatever
# or     $(call in-docker-db,blue) bash -c whatever
in-docker-db = docker exec --user=mysql $(call docker-id,db,$(1))

master-wp  = $(in-docker-mgmt) wp --path=/srv/$(WP_ENV)/$(SITE_NAME)/htdocs/
standby-wp = $(call in-docker-mgmt,$(STANDBY)) wp --path=/srv/$(STANDBY)/$(SITE_NAME)/htdocs/

# Usage: @$(call apt-install,mgmt,php7.0-xml)
# or     @$(call apt-install,mgmt,php7.0-xml,blue)
apt-install = docker exec $(call docker-id,$(1),$(3)) apt -y install $(2) >/dev/null 2>&1

# Usage: $(docker-htdocs)
# or     $(call docker-htdocs,blue)
docker-htdocs = /srv/$(if $(1),$(1),$(WP_ENV))/$(SITE_NAME)/htdocs

srv-backup-path-outside = jahia2wp_$(MASTER)/volumes/srv/backup

# Usage : $(call mysqldump,--all-databases)
mysqldump = $(call in-docker-db,) bash -c 'exec mysqldump -uroot -p"$$MYSQL_ROOT_PASSWORD" $(1)'

dbname = $(shell $(call in-docker-mgmt,) cat $(docker-htdocs)/wp-config.php | perl -ne "m|define.*DB_NAME'.*'(.*?)'| && print qq'\$$1\n';")
