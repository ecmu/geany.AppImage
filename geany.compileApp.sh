#! /bin/bash

#Global variables set by caller
#APP=geany
#LOWERAPP=${APP,,} 
#APPDIR=$(readlink -f appdir)

#set -x
#set -e

#=== Get App source

URL=$(wget --quiet "http://download.geany.org/" -O - | grep -e "geany-.*\.tar\.gz<" | tail -n 1 | cut -d '"' -f 2)
wget -c "http://download.geany.org/$URL"
tar xf geany-*.tar.gz

#=== Compile

cd geany-*/
./configure --enable-gtk3=no --enable-binreloc --prefix=/usr
make -j$(nproc)
make -j$(nproc) check
make install DESTDIR=${APPDIR}
