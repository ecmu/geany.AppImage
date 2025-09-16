#!/usr/bin/env bash
#set -x #echo on
set -e #Exists on errors

SCRIPTPATH=$(cd $(dirname "$BASH_SOURCE") && pwd)
echo "SCRIPTPATH = $SCRIPTPATH"
pushd ${SCRIPTPATH}

export APP=Geany
export LOWERAPP=${APP,,}
export APPDIR="${SCRIPTPATH}/appdir"

#region === Dependencies versions

JQ_VERSION=1.8.1

#endregion
#region === Define App version to build

#Workaround for build outside github: "env" file should then contain exports of github variables.
#Example for "env" file :
#  #!/usr/bin/env bash
#  #set -x #echo on
#  #set -e #Exists on errors
#
#  export GITHUB_REF_NAME=2.1.0
#  echo GITHUB_REF_NAME=$GITHUB_REF_NAME
#
#  #export BUILD_IGN_MAIN=yes
#  #export BUILD_IGN_PLUGIN=yes
#  #export BUILD_IGN_APPIMAGE=yes
if [ -f "./env" ];
then
  source ./env
fi

if [ "$GITHUB_REF_NAME" = "" ];
then
	echo "Please define/export tag for this release (GITHUB_REF_NAME). Maybe in './.env' file."
	exit 1
fi

#Get App version from tag, excluding suffixe "-Revision" used only for specific AppImage builds...
export VERSION=$(echo $GITHUB_REF_NAME | cut -d'-' -f1)
export VERSION_SHORT=${VERSION%.*}

#endregion
#region === Package installations for building

#Notes:
# - appstream 			  => used by AppImageTool
#	- subversion 			  => for geany-themes
# - patchelf				  => for linuxdeploy-plugin-gtk
# - librsvg2-dev		  => for bundling GTK3 (linuxdeploy-plugin-gtk)
BuildPackages="appstream subversion patchelf librsvg2-dev intltool"

echo ""
echo "=== Package installations for building: $BuildPackages"
echo ""

sudo apt update
sudo apt install --fix-broken
sudo apt install --yes $BuildPackages

# This normally would get installed later as a dependency. Just install
# it here and use noninteractive mode to prevent prompts for entering
# tz info
sudo DEBIAN_FRONTEND=noninteractive apt install --yes tzdata

#endregion
#region === AppDir

if [ ! -d "${APPDIR}/usr" ];
then
  mkdir --parents "${APPDIR}/usr"
fi

export PKG_CONFIG_PATH=${PKG_CONFIG_PATH:+$PKG_CONFIG_PATH:}${APPDIR}/usr/lib/pkgconfig
export C_INCLUDE_PATH=${C_INCLUDE_PATH:+$C_INCLUDE_PATH:}${APPDIR}/usr/include/geany:${APPDIR}/usr/include/geany/scintilla:${APPDIR}/usr/include/geany/tagmanager
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${APPDIR}/usr/lib:${APPDIR}/usr/local/lib

#endregion
#region === Add JQ (JSON parser)

if [ "$(uname -m)" = "x86_64" ]; then
  MACH="amd64"
else
  MACH="arm64"
fi

JQ_BIN=${SCRIPTPATH}/jq-linux-${MACH}

if [ ! -f "${JQ_BIN}" ];
then
  wget --continue "https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${MACH}"
  chmod +x "${JQ_BIN}"
fi

#endregion
#region === Get and build main App sources

echo ""
echo "=== Get and build main App sources (BUILD_IGN_MAIN = $BUILD_IGN_MAIN)"
echo ""

if [ ! -f "./${LOWERAPP}-${VERSION}.tar.gz" ];
then
	JSON=$(wget -q -O - https://api.github.com/repos/geany/geany/releases)
	URL=$(echo $JSON | $JQ_BIN '.[] | select(.tag_name == env.VERSION) | .assets[] | select(.content_type == "application/gzip") | .browser_download_url')
  if [ "$URL" = "" ];
  then
    echo "$APP sources not found for $VERSION in https://api.github.com/repos/geany/geany/releases"
    echo "Here are the 5 latest available versions:"
    echo $JSON | $JQ_BIN '.[:5] | .[] | { version: .tag_name }'
    exit 1
  fi
  wget --continue $(echo $URL | tr -d "'" | tr -d '"') --output-document="${LOWERAPP}-${VERSION}.tar.gz"
  rm --recursive --force "./${LOWERAPP}-${VERSION_SHORT}"
fi

if [ ! -d "./${LOWERAPP}-${VERSION_SHORT}" ];
then
  tar --extract --file="./${LOWERAPP}-${VERSION}.tar.gz"

  #Apply changes (good use of BinReloc)
  #Note : diff -ruN --label=src --label=src  OldDir/geany-2.1/src/ NewDir/geany-2.1/src/ >./geany-src.diff
  # => chaque "label" doit remplacer les noms complets des répertoires comparés. Réponse de Claude pas testée, donc à vérifier.
  pushd "./${LOWERAPP}-${VERSION_SHORT}"
  patch -p0 < "$SCRIPTPATH/geany-src.diff"
  popd
fi

if [ "$BUILD_IGN_MAIN" = "yes" ]; then
  echo ""
  echo "WARNING: $APP build is ignored by BUILD_IGN_MAIN"
  echo ""
else
  #Modèle à utiliser pour cette partie si problème = https://github.com/geany/geany/blob/master/.github/workflows/build.yml

  #Step: linux - Install dependencies
  sudo apt install --assume-yes --no-install-recommends \
            ccache \
            autopoint \
            doxygen \
            python3-docutils \
            python3-lxml \
            rst2pdf

  pushd "./${LOWERAPP}-${VERSION_SHORT}/"

  ./configure --prefix=/usr --enable-binreloc
  make -j$(nproc)
  #make -j$(nproc) check
  make install DESTDIR=${APPDIR}

  popd
fi

#endregion
#region === Get and build plugins

echo ""
echo "=== Get and build plugins (BUILD_IGN_PLUGIN = $BUILD_IGN_PLUGIN)"
echo ""

if [ ! -f "./${LOWERAPP}-plugins-${VERSION}.tar.gz" ]; then
	JSON=$(wget -q -O - https://api.github.com/repos/geany/geany-plugins/releases)
	URL=$(echo $JSON | $JQ_BIN '.[] | select(.tag_name == env.VERSION) | .tarball_url')
  if [ "$URL" = "" ];
  then
    echo "$APP plugin sources not found for $VERSION in https://api.github.com/repos/geany/geany-plugins/releases"
    echo "Here are the 5 latest available versions:"
    echo $JSON | $JQ_BIN '.[:5] | .[] | { version: .tag_name }'
    exit 1
  fi
  wget --continue $(echo $URL | tr -d "'" | tr -d '"') --output-document="${LOWERAPP}-plugins-${VERSION}.tar.gz"
  rm --recursive --force "./${LOWERAPP}-plugins-${VERSION}"
fi

if [ ! -d "./${LOWERAPP}-plugins-${VERSION_SHORT}" ]; then
  mkdir --parent "./${LOWERAPP}-plugins-${VERSION_SHORT}"
  tar --extract --file="./${LOWERAPP}-plugins-${VERSION}.tar.gz" --directory="./${LOWERAPP}-plugins-${VERSION_SHORT}" --strip-components=1
fi

if [ "$BUILD_IGN_PLUGIN" = "yes" ]; then
  echo ""
  echo "WARNING: $APP plugin build is ignored by BUILD_IGN_PLUGIN"
  echo ""
else
  # Modèle pour cette partie = https://github.com/geany/geany-plugins/blob/master/.github/workflows/build.yml

  pushd ./${LOWERAPP}-plugins-${VERSION_SHORT}/

  #Step: env
  export CONFIGURE_FLAGS="--prefix=/usr --disable-silent-rules"

  #Step: linux - Install Dependencies
  cat << EOF > /tmp/geany-plugins-dependencies
    # geany
    python3-docutils
    # geany-plugins
    check
    # debugger
    libvte-2.91-dev
    # geanygendoc
    libctpl-dev
    # geanylua
    liblua5.1-0-dev
    # geanypg
    libgpgme-dev
    # geanyvc
    libgtkspell-dev
    libgtkspell3-3-dev
    # geaniuspaste/updatechecker
    libsoup2.4-dev
    libsoup-3.0-dev
    # git-changebar
    libgit2-dev
    # markdown
    libmarkdown2-dev
    # markdown/webhelper
    libwebkit2gtk-4.0-dev
    libwebkit2gtk-4.1-dev
    # pretty-printer
    libxml2-dev
    # spellcheck
    libenchant-2-dev
    # cppcheck
    libpcre3-dev
EOF
  grep -v '^[ ]*#' /tmp/geany-plugins-dependencies | xargs sudo apt-get install --assume-yes --no-install-recommends

  #Step: linux - Configure
  if [ -f "./configure" ]; then
    ./configure $CONFIGURE_FLAGS
  elif [ -f "./autogen.sh" ]; then
    # Add previously built cppcheck to $PATH, for this and for succeeding steps
    #export "PATH=$PATH:${{ env.CPPCHECK_CACHE_PATH }}/build/bin"

    NOCONFIGURE=1 ./autogen.sh
    mkdir ./_build
    pushd ./_build
    { ../configure $CONFIGURE_FLAGS --enable-all-plugins || { cat config.log; exit 1; } ; }
    popd
  else
    echo "ERROR: No compilation instruction found for Plugins (missing configure AND autogen.sh)"
    exit 1
  fi

  #Step: linux - Build
  pushd ./_build
  make -j$(nproc)
  make -j$(nproc) install DESTDIR=${APPDIR}
  popd

  popd
fi

#endregion
#region === Include geany-themes

#pushd ${APPDIR}/usr/share/geany
#svn export https://github.com/geany/geany-themes.git/trunk/colorschemes --force
#popd

#endregion
#region === Build AppImage

echo ""
echo "=== Build AppImage (BUILD_IGN_APPIMAGE = $BUILD_IGN_APPIMAGE)"
echo ""

if [ "$BUILD_IGN_APPIMAGE" = "yes" ]; then
  echo ""
  echo "WARNING: AppImage build is ignored by BUILD_IGN_APPIMAGE"
  echo ""
else
  #Prepare AppDir
  linuxdeploy --appdir=${APPDIR} --plugin=gtk

  #Export to AppImage
  rm --recursive --force ${APPDIR}/apprun-hooks
  rm --force ${APPDIR}/AppRun.wrapped
  cp ${SCRIPTPATH}/AppRun ${APPDIR}
  linuxdeploy --appdir=${APPDIR} --output=appimage

  echo ""
  echo "AppImage generated = $(readlink -f $(ls Geany*.AppImage))"
  echo ""
fi

#endregion

popd
