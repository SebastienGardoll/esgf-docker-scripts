#!/bin/bash

################################# SETTINGS #####################################

readonly BASE_DIR_PATH="$(pwd)"
SCRIPT_PARENT_DIR_PATH="$(dirname $0)"; cd "${SCRIPT_PARENT_DIR_PATH}"
readonly SCRIPT_PARENT_DIR_PATH="$(pwd)" ; cd "${BASE_DIR_PATH}"

set -u

source "${SCRIPT_PARENT_DIR_PATH}/set_env"

readonly ARCHIVE_FILENAME='config.tar.xz'
readonly ARCHIVE_FILE_PATH="${SCRIPT_PARENT_DIR_PATH}/${ARCHIVE_FILENAME}"

############################ CONTROL VARIABLES #################################



################################ FUNCTIONS #####################################

function startup_cluster {

rm -f "${ARCHIVE_FILE_PATH}"

pushd "${DOCKER_HOME}" > /dev/null

echo "> create the configuration archive"
tar --owner=0 --group=0 -pcJvf "${ARCHIVE_FILE_PATH}" "${ESGF_CONFIG_DIRNAME}"

echo "> copy the configuration"
docker-machine ssh node0 "mkdir -p ${DOCKER_HOME} ; chmod go= ${DOCKER_HOME}"
docker-machine scp "${ARCHIVE_FILE_PATH}" node0:${DOCKER_HOME}
echo "> extract the configuration"
docker-machine ssh node0 "tar -xJvf ${DOCKER_HOME}/${ARCHIVE_FILENAME} -C ${DOCKER_HOME}"

echo "> copy the configuration"
docker-machine ssh node1 "mkdir -p ${DOCKER_HOME} ; chmod go= ${DOCKER_HOME}"
docker-machine scp "${ARCHIVE_FILE_PATH}" node1:${DOCKER_HOME}
echo "> extract the configuration"
docker-machine ssh node1 "tar -xJvf ${DOCKER_HOME}/${ARCHIVE_FILENAME} -C ${DOCKER_HOME}"

rm "${ARCHIVE_FILE_PATH}"

popd > /dev/null

echo "> update labels"

docker-machine ssh node0 "docker node update --label-add esgf_front_node=true node0"
docker-machine ssh node0 "docker node update --label-add esgf_idp_node=true node0"
docker-machine ssh node0 "docker node update --label-add esgf_index_node=true node0"
docker-machine ssh node0 "docker node update --label-add esgf_solr_node=true node0"
docker-machine ssh node0 "docker node update --label-add esgf_db_node=true node1"
docker-machine ssh node0 "docker node update --label-add esgf_data_node=true node1"
}


################################## MAIN ########################################

echo "> init configuration"
"${DOCKER_GIT_DIR_PATH}/scripts/esgf_node_init.sh"
chmod go= "${ESGF_CONFIG}"

startup_cluster

eval $(docker-machine env node0)

docker stack deploy -c "${DOCKER_GIT_DIR_PATH}/docker-stack.yml" esgf-stack

watch -n 1 docker service ls
