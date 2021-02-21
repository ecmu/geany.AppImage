#!/bin/bash

#Build image after deleting existing container and image
docker rm geany
docker image rm geany
docker build -t geany .

#Run "geany" image giving also name "geany" for container:
docker run --name geany geany

docker cp geany:/AppImageFullname.txt .
docker cp geany:$(cat ./AppImageFullname.txt) .
