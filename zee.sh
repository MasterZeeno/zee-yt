#!/bin/sh

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

[ -f "$VERSION_FILE" ] || update_version "0.0.0"
CURRENT_VERSION=$(cat "$VERSION_FILE")

check_dependencies curl unzip jq || exit 1

for type in monet black; do
    REPO_TYPE="${type}-og"
    ORIG_JSON_URL="$SITE/$ORIG_AUTHOR/$ORIG_REPO/main/$ORIG_REPO_ID/${REPO_TYPE}.json"
    JSON_FILE="$MODDIR/$REPO/${REPO_TYPE}.json"
    RELEASE_FILE="${REPO}-${REPO_TYPE}.zip"
    update
done