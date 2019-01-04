#! /bin/bash

#Global variables set by caller
#APP=geany
#LOWERAPP=${APP,,} 
#APPDIR=$(readlink -f appdir)

#set -x
#set -e

#=== Get App source

URL=$(wget --quiet "https://github.com/geany/geany/releases" -O - | grep -e "geany/archive.*\.tar\.gz" | head -n 1 | cut -d '"' -f 2)
FILENAME=$(echo $URL | cut -d '/' -f 5)
wget --continue "https://github.com${URL}" --output-document="geany-${FILENAME}"
tar xf geany-*.tar.gz

#=== Compile

cd geany-*/
./autogen.sh --enable-gtk3=no --enable-binreloc --prefix=/usr
make -j$(nproc)
make -j$(nproc) check
make install DESTDIR=${APPDIR}
