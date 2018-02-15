#!/bin/bash

################################# SETTINGS #####################################

readonly BASE_DIR_PATH="$(pwd)"
SCRIPT_PARENT_DIR_PATH="$(dirname $0)"; cd "${SCRIPT_PARENT_DIR_PATH}"
readonly SCRIPT_PARENT_DIR_PATH="$(pwd)" ; cd "${BASE_DIR_PATH}"

set -u

source "${SCRIPT_PARENT_DIR_PATH}/set_env"

echo "> init configuration"

pushd "${DOCKER_HOME}" > /dev/null

rm -fr "${ESGF_CONFIG}"
docker run -u ${USER} -v "$ESGF_CONFIG":/esg -e ESGF_HOSTNAME cedadev/esgf-setup generate-secrets
docker run -u ${USER} -v "$ESGF_CONFIG":/esg -e ESGF_HOSTNAME cedadev/esgf-setup generate-test-certificates
docker run -u ${USER} -v "$ESGF_CONFIG":/esg -e ESGF_HOSTNAME cedadev/esgf-setup create-trust-bundles

chmod go=r "${ESGF_CONFIG}/certificates/esg-hostcert-bundle.p12" ; chmod go=r "${ESGF_CONFIG}/certificates/slcsca/ca.key"

popd > /dev/null

pushd "${DOCKER_GIT_DIR_PATH}" /dev/null

docker-compose up -d

popd > /dev/null

watch -n 1 docker ps