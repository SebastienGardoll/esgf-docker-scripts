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

# standalone (default) | cluster (swarm master @node0)
# | remote (swarm master @desktop worker@cluster)
mode="${1-standalone}" 

################################ FUNCTIONS #####################################

function usage
{
  echo "standalone | cluster | remote"
}

function startup_cluster_remote {
echo "> start swarm manager"
docker swarm init
swarm_token="$(docker swarm join-token -q worker)"
#docker node update --availability drain "${SWARN_MANAGER_HOSTNAME}"

for node_index in `seq $1 ${NODE_MAX_INDEX}`;
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

case "${mode}" in
  "standalone") echo -e "**** run in standalone mode ****\n" ;;
  "cluster") echo -e "**** run in cluster mode ****\n" ;;
  "remote") echo -e "**** run in remote mode ****\n" ;;
  *) echo "#### unsupported '${mode}' mode. Abort ####"
     usage
     exit 1;;
esac

systemctl --no-pager status docker > /dev/null

if [ $? -ne 0 ]; then
  echo "> starting docker"
  sudo service docker start
fi

echo "> init configuration"
"${DOCKER_GIT_DIR_PATH}/scripts/esgf_node_init.sh"
chmod go= "${ESGF_CONFIG}"

case "${mode}" in
  "standalone") startup_standalone ;;
  "cluster") startup_cluster_remote 1 ;;
  "remote") startup_cluster_remote 0 ;;
  *) echo "#### unsupported '${mode}' mode. Abort ####"
     usage
     exit 1;;
esac

docker stack deploy -c "${DOCKER_GIT_DIR_PATH}/docker-stack.yml" esgf-stack

echo 'watch -n 1 docker service ls'

watch -n 1 docker service ls