#!/bin/sh
set -eu

: "${ICECAST_SOURCE_PASSWORD:?ICECAST_SOURCE_PASSWORD is required}"
: "${ICECAST_ADMIN_PASSWORD:?ICECAST_ADMIN_PASSWORD is required}"
ICECAST_MAX_LISTENERS="${ICECAST_MAX_LISTENERS:-500}"
ICECAST_HOSTNAME="${ICECAST_HOSTNAME:-localhost}"

esc() { printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'; }

sed -e "s|@SOURCE_PASSWORD@|$(esc "$ICECAST_SOURCE_PASSWORD")|g" \
    -e "s|@ADMIN_PASSWORD@|$(esc "$ICECAST_ADMIN_PASSWORD")|g" \
    -e "s|@MAX_LISTENERS@|$(esc "$ICECAST_MAX_LISTENERS")|g" \
    -e "s|@HOSTNAME@|$(esc "$ICECAST_HOSTNAME")|g" \
    /etc/icecast2/icecast.xml.template > /tmp/icecast.xml

chown icecast2 /tmp/icecast.xml
exec icecast2 -c /tmp/icecast.xml
