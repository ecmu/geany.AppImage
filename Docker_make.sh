#!/usr/bin/env bash
#set -x #echo on
#set -e #Exists on errors

#usage: 
#DOCKER_RESET=1 bash ./Docker_make.sh
#		=> make restarting new image

DKR_IMG_NAME=geany

SCRIPTPATH=$(cd $(dirname "$BASH_SOURCE") && pwd)
pushd "$SCRIPTPATH"

echo "DOCKER_RESET = $DOCKER_RESET"
if [ "$DOCKER_RESET" == "1" ] || [ "$(docker image ls ${DKR_IMG_NAME} | grep ${DKR_IMG_NAME})" == "" ]
then
  echo "Deleting existing container '${DKR_IMG_NAME}'..."
  docker stop ${DKR_IMG_NAME}
  docker rm ${DKR_IMG_NAME}

  echo "Deleting existing image '${DKR_IMG_NAME}'..."
  docker image rm ${DKR_IMG_NAME}
  
  echo "Building image '${DKR_IMG_NAME}'..."
  docker build --tag ${DKR_IMG_NAME} .

  echo "Running '${DKR_IMG_NAME}' image into '${DKR_IMG_NAME}' container..."
  docker run --interactive --tty --volume ${SCRIPTPATH}:/${DKR_IMG_NAME} --name ${DKR_IMG_NAME} ${DKR_IMG_NAME} /usr/bin/bash /${DKR_IMG_NAME}/make_appimage.sh
else
  echo "Running existing ${DKR_IMG_NAME} container..."
  docker start --attach ${DKR_IMG_NAME}
fi

popd
