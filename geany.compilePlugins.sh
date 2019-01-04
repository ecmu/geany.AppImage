#! /bin/bash

#Global variables set by caller
#APP=geany
#LOWERAPP=${APP,,} 
#APPDIR=$(readlink -f appdir)

#set -x
#set -e

#=== Get App source

URL=$(wget --quiet "https://github.com/geany/geany-plugins/releases" -O - | grep -e "geany-plugins/archive.*\.tar\.gz" | head -n 1 | cut -d '"' -f 2)
FILENAME=$(echo $URL | cut -d '/' -f 5)
wget --continue "https://github.com${URL}" --output-document="geany-plugins-${FILENAME}"
tar xf geany-plugins-*.tar.gz

#=== Compile

cd geany-plugins-*/
#NOCONFIGURE=1 ./autogen.sh --enable-all-plugins
./configure
make -j$(nproc)
make -j$(nproc) check
make install DESTDIR=${APPDIR}
