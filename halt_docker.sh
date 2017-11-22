#!/bin/bash

readonly BASE_DIR_PATH="$(pwd)"
SCRIPT_PARENT_DIR_PATH="$(dirname $0)"; cd "${SCRIPT_PARENT_DIR_PATH}"
readonly SCRIPT_PARENT_DIR_PATH="$(pwd)" ; cd "${BASE_DIR_PATH}"

source "${SCRIPT_PARENT_DIR_PATH}/set_env"

set -u

is_standalone="${1-true}"

echo "> stop esgf stack"
docker stack rm esgf-stack

sleep 5

if [[ "${is_standalone}" = "${FALSE}" ]]; then
  echo "> stop docker on cluster nodes"
  for node_index in `seq 0 ${NODE_MAX_INDEX}`;
  do
    #ssh root@${NODE_NAMES[${node_index}]} 'docker ps -aq |xargs docker rm'
    #ssh root@${NODE_NAMES[${node_index}]} 'docker volume ls -q | xargs docker volume rm --force'
    ssh root@${NODE_NAMES[${node_index}]} 'docker swarm leave ; service docker stop'
  done
fi

echo "> leave swarm cluster"
docker swarm leave --force

echo "> delete the containers"
docker ps -aq |xargs docker rm

echo "> delete the volumes"
docker volume ls -q | xargs docker volume rm --force

#echo "> stop docker daemon"
#sudo service docker stop
