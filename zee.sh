#!/bin/sh

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

[ -f "$VERSION_FILE" ] || update_version "0.0.0"
CURRENT_VERSION=$(cat "$VERSION_FILE")

check_dependencies curl unzip jq || exit 1
update