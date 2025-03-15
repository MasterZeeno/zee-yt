#!/bin/sh

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

update "${1:-MasterZeeno}" "${2:-zee-yt}" "${3:-monet}"
