FROM debian:oldstable

#=== Install required packages for building App (= "addons:apt:packages:" section from .travis.xml):

RUN apt update
RUN apt install --yes apt-utils 

#Note:
#	- wget subversion => for getting sources.
# - patchelf				=> for linuxdeploy-plugin-gtk
# - librsvg2-dev		=> for bundling GTK3 (linuxdeploy-plugin-gtk)
# - <others>				=> for app building
RUN apt install --yes wget subversion patchelf librsvg2-dev intltool libtool python-docutils python-lxml libgtk-3-dev

#=== "before_script:" section from .travis.yml

ENV APP=Geany
ENV LOWERAPP=geany
ENV APPDIR="/appdir"
CMD mkdir --parents ${APPDIR}

#=== Lance la compilation dans le container :
COPY ./make_geany.sh /
ENTRYPOINT ["/bin/bash", "/make_geany.sh"]
