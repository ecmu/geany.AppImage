#!/bin/bash
set -x #echo on
set -e #Exists on errors

SCRIPTPATH=.
SCRIPTPATH=$(dirname $(readlink -f $0))
SCRIPTPATH=${SCRIPTPATH%/}

alias ll="ls -al"

#===============================================================================
#===============================================================================

#RESET_APPDIR=1
#if [ "$RESET_APPDIR" = "1" ]
#then
#  if [ -d ${APPDIR} ]
#  then
#    rm --recursive ${APPDIR}
#  fi
#  
#  mkdir --parents ${APPDIR}
#  find ${APPDIR}
#fi

#===============================================================================
#=== travis.yml : script
#===============================================================================

#=== Get App source

URL=$(wget --quiet "https://github.com/geany/geany/releases" -O - | grep -e "geany/archive.*\.tar\.gz" | head -n 1 | cut -d '"' -f 2)
FILENAME=$(echo $URL | cut -d '/' -f 5)
wget --continue "https://github.com${URL}" --output-document="geany-${FILENAME}"
tar xf geany-*.tar.gz

export VERSION=$(ls geany-*.tar.gz | sed -r 's/.*geany-(.*).tar.gz/\1/')

#=== Compile main App

pushd geany-*/

#Compile main app:
./autogen.sh --enable-binreloc --prefix=/usr
# --enable-gtk3=no   => not recognized anymore => building is with GTK3...
make -j$(nproc)
make -j$(nproc) check
make install DESTDIR=${APPDIR}

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${APPDIR}/usr/lib/pkgconfig
export C_INCLUDE_PATH=$C_INCLUDE_PATH:${APPDIR}/usr/include/geany:${APPDIR}/usr/include/geany/scintilla:${APPDIR}/usr/include/geany/tagmanager
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${APPDIR}/usr/lib:${APPDIR}/usr/local/lib

popd

#=== Compile plugins

#Get App source
URL=$(wget --quiet "https://github.com/geany/geany-plugins/releases" -O - | grep -e "geany-plugins/archive.*\.tar\.gz" | head -n 1 | cut -d '"' -f 2)
FILENAME=$(echo $URL | cut -d '/' -f 5)
wget --continue "https://github.com${URL}" --output-document="geany-plugins-${FILENAME}"
tar xf geany-plugins-*.tar.gz

#Compile
pushd geany-plugins-*/
#NOCONFIGURE=1 ./autogen.sh --enable-all-plugins
#./autogen.sh --help
./autogen.sh --prefix=/usr
make -j$(nproc)
make -j$(nproc) check
make install DESTDIR=${APPDIR}
popd

#=== Include geany-themes

pushd ${APPDIR}/usr/share/geany
svn export https://github.com/geany/geany-themes.git/trunk/colorschemes --force
popd

#=== Build AppImage

cp ${APPDIR}/usr/share/icons/hicolor/scalable/apps/geany.svg ${APPDIR}/ # Why is this needed?
sed -i -e 's|Text;Editor|Text;Editor;|g' ${APPDIR}/usr/share/applications/geany.desktop # FIXME
sed -i -e 's|Keywords|X-Keywords|g' ${APPDIR}/usr/share/applications/geany.desktop # FIXME
wget -c -nv "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage"
chmod a+x linuxdeployqt-continuous-x86_64.AppImage
unset QTDIR; unset QT_PLUGIN_PATH ; unset LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${APPDIR}/usr/local/lib

#modprobe fuse
./linuxdeployqt-continuous-x86_64.AppImage ${APPDIR}/usr/share/applications/*.desktop -appimage --appimage-extract-and-run

#===

echo "AppImage generated = $(readlink -f $(ls Geany*.AppImage))"
readlink -f $(ls Geany*.AppImage) >AppImageFullname.txt
echo "SCRIPTPATH = ${SCRIPTPATH}/"
