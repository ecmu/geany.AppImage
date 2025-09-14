#https://hub.docker.com/_/ubuntu/
#ubuntu:focal: FROM ubuntu:20.04
#ubuntu:jammy:
FROM ubuntu:22.04

# Éviter les prompts interactifs pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --yes apt-utils

#=== Installer les outils de locale :

RUN apt-get install --yes locales tzdata && rm -rf /var/lib/apt/lists/*

# Générer et configurer les locales françaises
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
 && sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen \
 && locale-gen

# Définir les variables d'environnement pour les locales
ENV LANG=fr_FR.UTF-8
ENV LANGUAGE=fr_FR:fr
ENV LC_ALL=fr_FR.UTF-8

# Configurer le fuseau horaire (optionnel)
ENV TZ=Europe/Paris
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Reconfigurer tzdata pour éviter les problèmes
RUN dpkg-reconfigure -f noninteractive tzdata

#=== Install required packages for building App :

RUN apt-get update && apt-get install --yes sudo wget build-essential \
&& useradd -m docker \
&& echo "docker:docker" | chpasswd \
&& adduser docker sudo

#For convenience, allow fake user to use sudo without password.
RUN echo "docker ALL = NOPASSWD:ALL" >/etc/sudoers.d/docker
#Always log in with this fake user
USER docker
