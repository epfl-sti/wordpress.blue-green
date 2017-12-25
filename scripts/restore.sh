#!/bin/bash

# Zero-effort restore script to be embedded in tgz backups.
# Made to work in pre-prod as well as on one's own laptop.

die() {
    echo >&2 "$@"
    exit 2
}

if [ -f "$(dirname "$0")"/latest.tgz ]; then
    tgz_path="$(dirname "$0")"/latest.tgz
elif [ -f "$1" ]; then
    tgz_path="$(dirname "$0")"/latest.tgz
else
    die "Unable to find tar.gz archive to restore"
fi

case "$(find /srv/ -name htdocs|wc -l)" in
    1)
        htdocs="$(find /srv/ -name htdocs)" ;;
    0)
        die "Unable to find htdocs directory" ;;
    *)
        die "Multiple htdocs directories found under /srv/, bailing out in confusion" ;;
esac

set -e -x

cd "$(dirname "$tgz_path")"

tar -zxvf "$tgz_path" wordpress.xml
tar -C"$htdocs" -zxvf "$tgz_path" wp-content/
wp --path="$htdocs" import --authors=skip wordpress.xml
wp --path="$htdocs" media regenerate --yes
