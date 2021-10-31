#!/bin/bash
set -x #echo on
set -e #Exists on errors

#TODO : get version from github tag
export VERSION=1.38.0

SCRIPTPATH=.
SCRIPTPATH=$(dirname $(readlink -f $0))
SCRIPTPATH=${SCRIPTPATH%/}

alias ll="ls -al"
pushd ${SCRIPTPATH}

export APP=Geany
export LOWERAPP=geany
export APPDIR="${SCRIPTPATH}/appdir"

mkdir --parents ${APPDIR}

#=== AppDir

RESET_APPDIR=1
if [ "$RESET_APPDIR" = "1" ]
then
  if [ -d ${APPDIR} ]
  then
    rm --recursive ${APPDIR}
  fi
  
  mkdir --parents ${APPDIR}
  find ${APPDIR}
fi

#=== Get App source

if [ ! -f "./geany-${VERSION}.tar.gz" ];
then
  wget --continue "https://github.com/geany/geany/archive/refs/tags/${VERSION}.tar.gz" --output-document="geany-${VERSION}.tar.gz"
  rm --recursive --force "./geany-${VERSION}"
fi

if [ ! -d "./geany-${VERSION}" ];
then
  tar xf "./geany-${VERSION}.tar.gz"
fi

#Workaround to have active plugins saved with relative paths in conf file.
# diff -u src/prefix.h latest/prefix.h >prefix.patch
#Important note: "cd $AppDir/usr && ./bin/geany" must be done for this change to work.
patch --input=./prefix.patch "./geany-${VERSION}/src/prefix.h"

#=== Compile main App

pushd "geany-${VERSION}/"

#Compile main app:
./autogen.sh --prefix=/usr --enable-binreloc
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

if [ ! -f "./geany-plugins-${VERSION}.tar.gz" ];
then
  wget --continue "https://github.com/geany/geany-plugins/archive/refs/tags/${VERSION}.tar.gz" --output-document="geany-plugins-${VERSION}.tar.gz"
  rm --recursive --force "./geany-plugins-${VERSION}"
fi

if [ ! -d "./geany-plugins-${VERSION}" ];
then
  tar xf geany-plugins-${VERSION}.tar.gz
fi

#Compile
pushd geany-plugins-${VERSION}/
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

wget -c "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh" --output-document=linuxdeploy-plugin-gtk
chmod a+x ./linuxdeploy-plugin-gtk
wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
chmod a+x ./linuxdeploy-x86_64.AppImage

#Prépare AppDir
./linuxdeploy-x86_64.AppImage --appimage-extract-and-run --appdir=${APPDIR} --plugin=gtk
# --custom-apprun=${SCRIPTPATH}/AppRun
# --icon-file mypackage.png --desktop-file mypackage.desktop

#Le convertit en AppImage
rm --recursive --force ${APPDIR}/apprun-hooks
rm --force ${APPDIR}/AppRun.wrapped
cp ${SCRIPTPATH}/AppRun ${APPDIR}
./linuxdeploy-x86_64.AppImage --appimage-extract-and-run --appdir=${APPDIR} --output=appimage

#===

echo "AppImage generated = $(readlink -f $(ls Geany*.AppImage))"
readlink -f $(ls Geany*.AppImage) >AppImageFullname.txt

popd
