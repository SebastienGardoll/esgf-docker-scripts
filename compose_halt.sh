#!/bin/bash

readonly BASE_DIR_PATH="$(pwd)"
SCRIPT_PARENT_DIR_PATH="$(dirname $0)"; cd "${SCRIPT_PARENT_DIR_PATH}"
readonly SCRIPT_PARENT_DIR_PATH="$(pwd)" ; cd "${BASE_DIR_PATH}"

source "${SCRIPT_PARENT_DIR_PATH}/set_env"

set -u

pushd "${DOCKER_GIT_DIR_PATH}" > /dev/null

echo "> stop containers"
docker-compose stop
docker-compose down

echo "> delete volumes"
docker volume ls -q | xargs docker volume rm

popd > /dev/null