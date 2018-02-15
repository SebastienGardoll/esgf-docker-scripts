#!/bin/bash

readonly BASE_DIR_PATH="$(pwd)"
SCRIPT_PARENT_DIR_PATH="$(dirname $0)"; cd "${SCRIPT_PARENT_DIR_PATH}"
readonly SCRIPT_PARENT_DIR_PATH="$(pwd)" ; cd "${BASE_DIR_PATH}"

source "${SCRIPT_PARENT_DIR_PATH}/set_env"

set -u

function usage
{
  echo "standalone | cluster | remote"
}

# standalone (default) | cluster (swarm master @node0)
# | remote (swarm master @desktop worker@cluster)
mode="${1-standalone}" 

case "${mode}" in
  "standalone") echo -e "**** run in standalone mode ****\n" ;;
  "cluster") echo -e "**** run in cluster mode ****\n" ;;
  "remote") echo -e "**** run in remote mode ****\n" ;;
  *) echo "#### unsupported '${mode}' mode. Abort ####"
     usage
     exit 1;;
esac

echo "> stop esgf stack"
docker stack rm esgf-stack

sleep 5

if [[ "${mode}" != "standalone" ]]; then
  
  case "${mode}" in 
    "cluster") starting_node=1 ;;
    "remote") starting_node=0 ;;
    *) echo "#### unsupported '${mode}' mode. Abort ####"
       usage
       exit 1;;
  esac
    
  echo "> stop docker on cluster nodes"
  for node_index in `seq ${starting_node} ${NODE_MAX_INDEX}`;
  do
    ssh root@${NODE_NAMES[${node_index}]} 'echo "  > stop containers" ; docker ps -aq |xargs docker stop -t 1'
    ssh root@${NODE_NAMES[${node_index}]} 'echo "  > delete containers" ; docker ps -aq |xargs docker rm'
    ssh root@${NODE_NAMES[${node_index}]} 'echo "  > delete volumes" ; docker volume ls -q | xargs docker volume rm --force'
    ssh root@${NODE_NAMES[${node_index}]} 'echo "  > quit swarm & stop docker daemon" ;docker swarm leave ; service docker stop'
  done
fi

echo "> leave swarm cluster"
docker swarm leave --force

return_code=$(docker ps -aq |wc -l)
if [ ${return_code} -gt 0 ]; then
  echo "> stop the containers"
  docker ps -aq |xargs docker stop -t 1

  echo "> delete the containers"
  docker ps -aq |xargs docker rm
fi

return_code=$(docker volume ls -q |wc -l)
if [ ${return_code} -gt 0 ]; then
  echo "> delete the volumes"
  docker volume ls -q | xargs docker volume rm --force
fi

#echo "> stop docker daemon"
#sudo service docker stop
