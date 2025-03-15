#!/bin/sh

MODDIR=${0%/*}
. "$MODDIR/utils.sh"

update "${1:-monet}"