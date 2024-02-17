#!/usr/bin/env bash

# /opt/incus-driver/prepare.sh

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh # Get variables from base.

set -eo pipefail

# trap any error, and mark it as a system failure.
trap "exit $SYSTEM_FAILURE_EXIT_CODE" ERR

add_extra_incus_remote() {
    #grep -q "extra " <<< $(incus remote ls) || incus remote add extra https://incus.example.com:8443 --accept-certificate --public
}

start_container () {
    echo "Try to start: $CUSTOM_ENV_CI_JOB_IMAGE"
    if incus info "$CONTAINER_ID" >/dev/null 2>/dev/null ; then
        echo 'Found old container, deleting'
        incus delete -f "$CONTAINER_ID"
    fi


    # FIXME: floating aliases at most get updated every 1h, this is undesired behaviour
    # when an image is updated to be used as buildagent, therefore we resolve the hash
    # and launch the instance from it: https://discuss.linuxcontainers.org/t/images-not-updating-even-with-auto-update-true/11229
    IMAGE_FLAGS=$(echo "$CUSTOM_ENV_CI_JOB_IMAGE" | cut -d' ' -s -f2-)
    IMAGE_REMOTE=$(echo "$CUSTOM_ENV_CI_JOB_IMAGE" | cut -d: -f1)

    IMAGE_INFO_FLAGS=""
    if [[ $IMAGE_FLAGS == *"--vm"* ]]; then
        IMAGE_INFO_FLAGS="--vm"
    fi

    IMAGE_FINGERPRINT=$( \
        incus image info $(echo "$CUSTOM_ENV_CI_JOB_IMAGE" | cut -d' ' -f1) $IMAGE_INFO_FLAGS | \
        grep 'Fingerprint: ' | \
        # remove the 'Fingerprint: ' prefix
        cut -d: -f2 | \
        # strip whitespaces
        xargs \
    )

    CUSTOM_ENV_CI_JOB_IMAGE="$IMAGE_REMOTE:$IMAGE_FINGERPRINT $IMAGE_FLAGS"

    echo "Using incus image: $CUSTOM_ENV_CI_JOB_IMAGE"

    incus init $CUSTOM_ENV_CI_JOB_IMAGE "$CONTAINER_ID"

    # Wait for the container to really start, if many containers are spawned at the
    # same time we might need to retry for a while because of the certificates
    for i in $(seq 1 60); do
        if incus start "$CONTAINER_ID"; then
            break
        fi

        if [ "$i" == "60" ]; then
            echo 'Waited for 60 seconds to start container, exiting..'
            # Inform GitLab Runner that this is a system failure, so it
            # should be retried.
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi

        sleep 1s
    done

    # Wait for container to start, we are using systemd to check this,
    # for the sake of brevity.
    for i in $(seq 1 60); do
        if incus exec "$CONTAINER_ID" -- sh -c "systemctl is-system-running | grep -qE 'running|degraded'" >/dev/null 2>/dev/null; then
            break
        fi

        if [ "$i" == "60" ]; then
            echo 'Waited for 60 seconds for `is-system-running` to change to running or degraded, exiting..'
            # Inform GitLab Runner that this is a system failure, so it
            # should be retried.
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        fi

        sleep 1s
    done
}

install_dependencies () {
    # Install basic utility tools.
    # Install Git LFS, git comes pre installed with ubuntu image.
    incus exec "$CONTAINER_ID" -- sh -c "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --yes wget curl git git-lfs" > /dev/null

    # Install gitlab-runner binary since we need for cache/artifacts.
    incus exec "$CONTAINER_ID" -- sh -c 'curl -sL --output /usr/local/bin/gitlab-runner "https://gitlab-runner-downloads.s3.amazonaws.com/latest/binaries/gitlab-runner-linux-amd64"'
    incus exec "$CONTAINER_ID" -- sh -c "chmod +x /usr/local/bin/gitlab-runner"
}

echo "Running in $CONTAINER_ID"

add_extra_incus_remote

start_container

install_dependencies
