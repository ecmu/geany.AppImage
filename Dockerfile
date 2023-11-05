#https://hub.docker.com/_/ubuntu/
FROM ubuntu:20.04

#=== Install required packages for building App :

RUN apt-get update \
&& apt-get install --yes apt-utils \
&& DEBIAN_FRONTEND=noninteractive apt-get install --yes sudo locales wget build-essential \
&& useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

#For convenience, allow fake user to use sudo without password.
RUN echo "docker ALL = NOPASSWD:ALL" >/etc/sudoers.d/docker
#Always log in with this fake user
USER docker
