#!/bin/bash

# Zero-effort restore script to be embedded in tgz backups.
# Made to work in pre-prod as well as on one's own laptop.

set -e


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
WP="wp --path=$htdocs"

wp_import () {
    set -x
    cd "$(dirname "$tgz_path")"

    tar -zxvf "$tgz_path" wordpress.xml
    cat > import_no_ssl.php <<"EOF"
<?php
/**
 * Disable SSL checks during "wp import"
 */
WP_CLI::add_wp_hook('http_request_args', function ( $args, $url ) {
    $args['sslverify'] = false;
    return $args;
}, 10, 2);
EOF
    $WP import --require="./import_no_ssl.php" --authors=skip wordpress.xml
    $WP media regenerate --yes
    set +x
}

wp_mirror () {
    dbname=$(perl -ne "m|define.*DB_NAME'.*'(.*?)'| && print qq'\$1\n';" < "$htdocs"/wp-config.php)
    set -x
    cd "$(dirname "$tgz_path")"
    tar -C "$htdocs" -zxvf "$tgz_path" wp-content/
    tar -zxvf "$tgz_path" dump-wp.sql
    mysql_wrapper "$dbname" dump-wp.sql
}

mysql_wrapper () {
    set +x
    mysql -u "$MYSQL_SUPER_USER" --password="$MYSQL_SUPER_PASSWORD" -h "$MYSQL_DB_HOST" "$1" < "$2"
}

case "$1" in
    --empty)
        set -x
        $WP site empty --uploads --yes
        wp_import
        ;;
    "")
        wp_import
        ;;
    --mirror)
        wp_mirror
        ;;
esac
