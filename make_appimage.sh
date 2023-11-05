#!/usr/bin/env bash
set -x #echo on
set -e #Exists on errors

SCRIPTPATH=$(cd $(dirname "$BASH_SOURCE") && pwd)
echo "SCRIPTPATH = $SCRIPTPATH"
pushd ${SCRIPTPATH}

export APP=Geany
export LOWERAPP=${APP,,}
export APPDIR="${SCRIPTPATH}/appdir"

#=== Dependencies versions

JQ_VERSION=1.7

#=== Define App version to build

#Workaround for build outside github: "env" file should then contain exports of github variables.
if [ -f "./env" ];
then
  source ./env
fi

if [ "$GITHUB_REF_NAME" = "" ];
then
	echo "Please define tag for this release (GITHUB_REF_NAME)"
	exit 1
fi

#Get App version from tag, excluding suffixe "-Revision" used only for specific AppImage builds...
export VERSION=$(echo $GITHUB_REF_NAME | cut -d'-' -f1)
export VERSION_SHORT=${VERSION%.*}

#=== Package installations for building

#Notes:
# - appstream 			=> used by AppImageTool
#	- subversion 			=> for geany-themes
# - patchelf				=> for linuxdeploy-plugin-gtk
# - librsvg2-dev		=> for bundling GTK3 (linuxdeploy-plugin-gtk)
# - <others>				=> for app building

sudo DEBIAN_FRONTEND=noninteractive apt-get install --yes appstream subversion patchelf librsvg2-dev \
intltool libtool python-docutils python-lxml libgtk-3-dev

#=== AppDir

if [ ! -d "${APPDIR}/usr" ];
then
  mkdir --parents "${APPDIR}/usr"
fi

#=== Add JQ (JSON parser)

JQ_BIN=${SCRIPTPATH}/jq-linux64

if [ ! -f "${JQ_BIN}" ];
then
  wget --continue "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux64"
  chmod +x "${JQ_BIN}"
fi

#=== Get App source

if [ ! -f "./${LOWERAPP}-${VERSION}.tar.gz" ];
then
	JSON=$(wget -q -O - https://api.github.com/repos/geany/geany/releases)
	URL=$(echo $JSON | ./jq-linux64 '.[] | select(.tag_name == env.VERSION) | .assets[] | select(.content_type == "application/gzip") | .browser_download_url')
  wget --continue $(echo $URL | tr -d "'" | tr -d '"') --output-document="${LOWERAPP}-${VERSION}.tar.gz"
  rm --recursive --force "./${LOWERAPP}-${VERSION_SHORT}"
fi

if [ ! -d "./${LOWERAPP}-${VERSION_SHORT}" ];
then
  tar --extract --file="./${LOWERAPP}-${VERSION}.tar.gz"
fi

#=== Compile main App

pushd "./${LOWERAPP}-${VERSION_SHORT}/"

./configure --prefix=/usr --enable-binreloc
make -j$(nproc)
#make -j$(nproc) check
make install DESTDIR=${APPDIR}

export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:${APPDIR}/usr/lib/pkgconfig
export C_INCLUDE_PATH=$C_INCLUDE_PATH:${APPDIR}/usr/include/geany:${APPDIR}/usr/include/geany/scintilla:${APPDIR}/usr/include/geany/tagmanager
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${APPDIR}/usr/lib:${APPDIR}/usr/local/lib

popd

#=== Get and Compile plugins

if [ ! -f "./${LOWERAPP}-plugins-${VERSION}.tar.gz" ];
then
	JSON=$(wget -q -O - https://api.github.com/repos/geany/geany-plugins/releases)
	URL=$(echo $JSON | ./jq-linux64 '.[] | select(.tag_name == env.VERSION) | .assets[] | select(.content_type == "application/gzip") | .browser_download_url')
  wget --continue $(echo $URL | tr -d "'" | tr -d '"') --output-document="${LOWERAPP}-plugins-${VERSION}.tar.gz"
  rm --recursive --force "./${LOWERAPP}-plugins-${VERSION}"
fi

if [ ! -d "./${LOWERAPP}-plugins-${VERSION_SHORT}" ];
then
  tar --extract --file="./${LOWERAPP}-plugins-${VERSION}.tar.gz"
fi

#Compile
pushd ./${LOWERAPP}-plugins-${VERSION_SHORT}/
./configure --prefix=/usr --enable-binreloc
make -j$(nproc)
#make -j$(nproc) check
make install DESTDIR=${APPDIR}
popd

#=== Include geany-themes

pushd ${APPDIR}/usr/share/geany
svn export https://github.com/geany/geany-themes.git/trunk/colorschemes --force
popd

#=== Build AppImage

wget -c "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh" --output-document=linuxdeploy-plugin-gtk
chmod a+x ./linuxdeploy-plugin-gtk
wget -c "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
chmod a+x ./linuxdeploy-x86_64.AppImage

#Prepare AppDir
./linuxdeploy-x86_64.AppImage --appimage-extract-and-run --appdir=${APPDIR} --plugin=gtk

#Export to AppImage
rm --recursive --force ${APPDIR}/apprun-hooks
rm --force ${APPDIR}/AppRun.wrapped
cp ${SCRIPTPATH}/AppRun ${APPDIR}
./linuxdeploy-x86_64.AppImage --appimage-extract-and-run --appdir=${APPDIR} --output=appimage

#===

echo "AppImage generated = $(readlink -f $(ls Geany*.AppImage))"

popd
