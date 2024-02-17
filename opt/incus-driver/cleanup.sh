#!/usr/bin/env bash

# /opt/incus-driver/cleanup.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base.

echo "Deleting container $CONTAINER_ID"

incus delete --force "$CONTAINER_ID" || echo "Removing $CONTAINER_ID failed trying again" && incus delete --verbose --force "$CONTAINER_ID"
