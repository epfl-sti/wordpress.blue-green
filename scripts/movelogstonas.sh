#!/bin/bash

set -x -e

# number time 24 hours, default to 72 hours
: ${LOG_OLDER_THAN:=3}
# where to move the log to, defaut to /srv/sti.epfl.ch/backup/logs/
: ${LOG_MOVE_TO:=/srv/sti.epfl.ch/backup/logs/}

for i in green blue
do
    echo "Moving logs for $i"
    find /srv/sti.epfl.ch/jahia2wp_$i/volumes/srv/$i/logs -type f -mtime +$LOG_OLDER_THAN -exec mv -t $LOG_MOVE_TO$i {} + 
    echo "$LOG_MOVE_TO$i/"
done
