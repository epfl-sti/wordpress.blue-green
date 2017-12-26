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

find_cmd="find /srv/ -type d -name htdocs"
case "$($find_cmd|wc -l)" in
    1)
        htdocs="$($find_cmd)" ;;
    0)
        die "Unable to find htdocs directory" ;;
    *)
        die "Multiple htdocs directories found under /srv/, bailing out in confusion" ;;
esac

set -e -x

cd "$(dirname "$tgz_path")"

tar -zxvf "$tgz_path" wordpress.xml
cat > import_no_ssl.php <<"EOF"
<?php
/**
 * Disable SSL checks during "wp import"
 */
WP_CLI::add_wp_hook('http_request_args', function ( $args, $url ) {
    error_log("http_request_args for $url");
	$args['sslverify'] = false;
	return $args;
}, 10, 2);
EOF
tar -C"$htdocs" -zxvf "$tgz_path" wp-content/
wp --path="$htdocs" import --require="./import_no_ssl.php" --authors=skip wordpress.xml
wp --path="$htdocs" media regenerate --yes
