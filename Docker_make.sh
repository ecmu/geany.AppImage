#!/usr/bin/bash

DOCKER_IMAGE_NAME=geany

#===

SCRIPTPATH=.
SCRIPTPATH=$(dirname $(readlink -f $0))
#SCRIPTPATH=${SCRIPTPATH%/}

#Build image after deleting existing container and image
docker rm ${DOCKER_IMAGE_NAME}
docker image rm ${DOCKER_IMAGE_NAME}
docker build -t ${DOCKER_IMAGE_NAME} .

#Run "geany" image giving also name "geany" for container:
docker run --volume ${SCRIPTPATH}:/geany ${DOCKER_IMAGE_NAME} /bin/bash /geany/make_geany.sh
