#!/bin/bash -e
topdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[[ -z "$CC" || -z "$CXX" ]] && exit 255
variant=win32
[[ "$(basename "$CXX")" == "x86_64-"* ]] && variant=win64
with_sdl=0
[[ "$extras" == *"-sdl"* ]] && with_sdl=1
#with_gl3=0
#[[ "$extras" == *"-gl3"* ]] && with_gl3=1

libjpeg_version=2.1.5.1
libpng_version=1.6.39
sdl2_version=2.28.1
zlib_version=1.2.13

download () {
	local url=$1
	local filename=${url##*/}
	local foldername=${filename%%[.-]*}

	[ -d "./$foldername" ] && return 0
    [ -e "$filename" ] || wget "$url" -O "$filename"
	sha256sum -w -c <(grep -F "$filename" "$topdir/sha256sums.txt")
	unzip -o "$filename" -d "$foldername"
}

mkdir -p libs
pushd libs
libs=$PWD
download "http://minetest.kitsunemimi.pw/libjpeg-$libjpeg_version-$variant.zip"
download "http://minetest.kitsunemimi.pw/libpng-$libpng_version-$variant.zip"
[ $with_sdl -eq 1 ] && download "http://minetest.kitsunemimi.pw/sdl2-$sdl2_version-$variant.zip"
download "http://minetest.kitsunemimi.pw/zlib-$zlib_version-$variant.zip"
popd

tmp=(
	-DCMAKE_SYSTEM_NAME=Windows \
	-DPNG_LIBRARY=$libs/libpng/lib/libpng.dll.a \
	-DPNG_PNG_INCLUDE_DIR=$libs/libpng/include \
	-DJPEG_LIBRARY=$libs/libjpeg/lib/libjpeg.dll.a \
	-DJPEG_INCLUDE_DIR=$libs/libjpeg/include \
	-DZLIB_LIBRARY=$libs/zlib/lib/libz.dll.a \
	-DZLIB_INCLUDE_DIR=$libs/zlib/include
)
[ $with_sdl -eq 1 ] && tmp+=(
	-DUSE_SDL2=ON
	-DCMAKE_PREFIX_PATH=$libs/sdl2/lib/cmake
)
#[ $with_gl3 -eq 1 ] && tmp+=(-DENABLE_OPENGL=OFF -DENABLE_OPENGL3=ON)

cmake . "${tmp[@]}"
make -j$(nproc)

if [ "$1" = "package" ]; then
	make DESTDIR=$PWD/_install install
	# strip library
	"${CXX%-*}-strip" --strip-unneeded _install/usr/local/lib/*.dll
	# bundle the DLLs that are specific to Irrlicht (kind of a hack)
	shopt -s nullglob
	cp -p $libs/*/bin/{libjpeg,libpng,SDL}*.dll _install/usr/local/lib/
	# create a ZIP
	(cd _install/usr/local; zip -9r "$OLDPWD/irrlicht-$variant$extras.zip" -- *)
fi
exit 0
