#!/bin/bash

USER_ID=${LOCAL_UID:-1000}
GROUP_ID=${LOCAL_GID:-1000}
DOCKER_GROUP_ID=${LOCAL_DOCKER_GID:-996}

echo "Starting with UID: $USER_ID, GID: $GROUP_ID"
useradd -u $USER_ID -o -m user
groupmod -g $GROUP_ID user
export HOME=/home/user

groupadd docker
groupmod -g $DOCKER_GROUP_ID docker
usermod -aG docker user

exec /usr/sbin/gosu user "$@"