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

is_standalone="${1-false}"

################################ FUNCTIONS #####################################

function startup_cluster {
for node_index in `seq 0 ${NODE_MAX_INDEX}`;
do
  echo "> clean ${NODE_NAMES[${node_index}]}"
  ssh root@${NODE_NAMES[${node_index}]} "rm -fr ${DOCKER_HOME}"
done

rm -f "${ARCHIVE_FILE_PATH}"

pushd "${DOCKER_HOME}" > /dev/null

echo "> create the configuration archive"
tar --owner=0 --group=0 -pcJvf "${ARCHIVE_FILE_PATH}" "${ESGF_CONFIG_DIRNAME}" > /dev/null

for node_index in `seq 0 ${NODE_MAX_INDEX}`;
do
  echo "> copy the configuration"
  ssh root@${NODE_NAMES[${node_index}]} "mkdir -p ${DOCKER_HOME} ; chmod go= ${DOCKER_HOME}"
  scp "${ARCHIVE_FILE_PATH}" root@${NODE_NAMES[${node_index}]}:${DOCKER_HOME}
  echo "> extract the configuration"
  ssh root@${NODE_NAMES[${node_index}]} "tar -xavf ${DOCKER_HOME}/${ARCHIVE_FILENAME} -C ${DOCKER_HOME} > /dev/null"
done

rm "${ARCHIVE_FILE_PATH}"

popd > /dev/null

echo "> start swarm manager"
docker swarm init
swarm_token="$(docker swarm join-token -q worker)"
#docker node update --availability drain "${SWARN_MANAGER_HOSTNAME}"

for node_index in `seq 0 ${NODE_MAX_INDEX}`;
do
  
  echo "> add ${NODE_NAMES[${node_index}]} to the swarm cluster"
  ssh root@${NODE_NAMES[${node_index}]} 'systemctl --no-pager status docker > /dev/null ; test $? -ne 0 && service docker start'
  ssh root@${NODE_NAMES[${node_index}]} "docker swarm join --token ${swarm_token} ${IP_SWARM_MANAGER}:${DEFAULT_PORT}"
done

docker node update --label-add esgf_front_node=true $NODE0
docker node update --label-add esgf_idp_node=true $NODE0
docker node update --label-add esgf_index_node=true $NODE0
docker node update --label-add esgf_solr_node=true $NODE0
docker node update --label-add esgf_db_node=true $NODE1
docker node update --label-add esgf_data_node=true $NODE1
}

function startup_standalone {
 echo "> start swarm manager"
 docker swarm init
 swarm_token="$(docker swarm join-token -q worker)" 
 
 docker node update --label-add esgf_front_node=true $SWARN_MANAGER_HOSTNAME
 docker node update --label-add esgf_idp_node=true $SWARN_MANAGER_HOSTNAME
 docker node update --label-add esgf_index_node=true $SWARN_MANAGER_HOSTNAME
 docker node update --label-add esgf_solr_node=true $SWARN_MANAGER_HOSTNAME
 docker node update --label-add esgf_db_node=true $SWARN_MANAGER_HOSTNAME
 docker node update --label-add esgf_data_node=true $SWARN_MANAGER_HOSTNAME
}

################################## MAIN ########################################

systemctl --no-pager status docker > /dev/null

if [ $? -ne 0 ]; then
  echo "> starting docker"
  sudo service docker start
fi

echo "> init configuration"
"${DOCKER_GIT_DIR_PATH}/scripts/esgf_node_init.sh"
chmod go= "${ESGF_CONFIG}"

if [[ "${is_standalone}" = "${TRUE}" ]]; then
  startup_standalone
else
  startup_cluster
fi

docker stack deploy -c "${DOCKER_GIT_DIR_PATH}/docker-stack.yml" esgf-stack

watch -n 1 docker service ls
