#!/bin/sh

set -eo pipefail

PYTHON_VERSION='3.7'


# ==============================================================================
#   Do not edit below this line!
# ==============================================================================


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FRAMEWORK_NAME='Python'$(echo $PYTHON_VERSION | sed 's/\./_/g')
PLATFORM="iOS"

# Make sure openssl is installed
# if brew list openssl 2>/dev/null >/dev/null; then
#     printf 'OpenSSL via Homebrew found.\n'
# else
#     printf 'OpenSSL via Homebrew is required. Installing OpenSSL...\n'
#     brew install openssl
# fi
# OPENSSL_PATH="$(brew --prefix openssl)"
OPENSSL_PATH=${SCRIPT_DIR}/dist

DIST_DIR="${SCRIPT_DIR}/dist"

# Make sure the framework output dir exists, but the framework not
mkdir -p "${DIST_DIR}/${PLATFORM}"
rm -rf "${DIST_DIR}/${PLATFORM}/${FRAMEWORK_NAME}.framework"

# Make sure wa have a clean cpython
git submodule update --init --recursive
cd './cpython'
git clean -fdxq
git reset --hard HEAD
git checkout "${PYTHON_VERSION}"

# Patch the configure file
patch ./configure < ../configure.patch

# All SDKs
SDK_MACOS="$(xcodebuild -showsdks | awk '/-sdk macosx/ {print $4}')"
SDK_IOS="$(xcodebuild -showsdks | awk '/-sdk iphoneos/ {print $4}')"
SDK_IOS_SIM="$(xcodebuild -showsdks | awk '/-sdk iphonesimulator/ {print $4}')"

# All Archs
ARCH_MACOS='x86_64'
ARCH_IOS='arm64'
ARCH_IOS_SIM='x86_64'

# Selected SDK/Arch
SDK="$SDK_IOS"
ARCH="$ARCH_IOS"

# Paths
SDK_ROOT=$(/usr/bin/env xcrun --sdk "$SDK" --show-sdk-path)
# CC="/usr/bin/env xcrun --sdk $SDK clang -arch $ARCH --sysroot=$SDK_ROOT"
# OTOOL="/usr/bin/env xcrun --sdk $SDK otool -arch $ARCH --sysroot=$SDK_ROOT"
CC="/usr/bin/env xcrun --sdk $SDK clang -arch $ARCH -isysroot $SDK_ROOT -mios-version-min=10.0"
OTOOL="/usr/bin/env xcrun --sdk $SDK otool -arch $ARCH -isysroot $SDK_ROOT -mios-version-min=10.0"
#LDFLAGS="-arch '$ARCH' -isysroot='${SDK_ROOT}'"


# TARGET_HOST_MACOS='i386-apple-macos'
TARGET_HOST_IOS='aarch64-apple-ios'
DARWIN_VERSION="$(uname -r)"
BUILD_HOST="x86_64-apple-darwin${DARWIN_VERSION}"


# temp
rm ./configure.ac

# Set up for framework building
./configure \
    MACOSX_DEPLOYMENT_TARGET= \
    IOS_DEPLOYMENT_TARGET=10.0 \
    UNIVERSALSDK="${SDK_ROOT}" \
    CC="$CC" \
    LD="$CC" \
    READELF="$OTOOL" \
    --host="$TARGET_HOST_IOS" \
    --build="$BUILD_HOST" \
    --enable-ipv6 \
    --with-pydebug \
    --without-ensurepip \
    --with-openssl="$OPENSSL_PATH" \
    --with-system-ffi \
    --with-system-libmpdec \
    --enable-framework="${DIST_DIR}/${PLATFORM}" \
    --with-framework-name="${FRAMEWORK_NAME}" \
    --prefix="${SCRIPT_DIR}/build/dummy" \
    ac_cv_file__dev_ptmx=no \
    ac_cv_file__dev_ptc=no
    # ac_cv_func_
    # --without-doc-strings \

# FIXME: Force disable stuff on iOS
sed -i '' -E "s/.*HAVE_(GETENTROPY|SENDFILE|CLOCK_SETTIME).*/\/\* #undef HAVE_\1 \*\//g" ./pyconfig.h
sed -i '' -E "s/.*WITH_NEXT_FRAMEWORK.*/\/\* #undef WITH_NEXT_FRAMEWORK \*\//g" ./pyconfig.h # TODO: can be disabled via configure.patch
sed -i '' -E "s/.*\#define HAVE_SYSTEM.*/\/\* #undef HAVE_SYSTEM \*\//g" ./Modules/posixmodule.c
sed -i '' -E "s/disabled_module_list = \[\]/disabled_module_list = \[\"_ctypes\"\, \"_decimal\", \"_tkinter\"]/g" ./setup.py

# _ctypes_test
# _curses
# _curses_panel
# _tkinter

#
# Is this all really necessary??
#

# # Remove `altbininstall` from `bininstall`
# sed -i '' -E "s/bininstall: altbininstall/bininstall:/g" ./Makefile

# # Remove `bininstall` and `maninstall` from `install`
# sed -i '' -E 's/bininstall maninstall//g' ./Makefile

# # Remove `altbininstall` and `libainstall` from `commoninstall`
# sed -i '' -E "s/altbininstall libinstall inclinstall libainstall/libinstall inclinstall/g" ./Makefile

# # Remove `frameworkinstallmaclib` from `frameworkinstallframework`
# sed -i '' -E "s/install frameworkinstallmaclib/install/g" ./Makefile

# install_name_tool -id @executable_path/Frameworks/Python3_7.framework/Python3_7 "prebuilt/iOS/Python3_7.framework/Python3_7"

# for i in "HAVE_GETENTROPY" "WITH_NEXT_FRAMEWORK" "HAVE_SYSTEM"; do
#     sed -i '' -E "s/.*(${i}).*/\/\* #undef \1 \*\//g" ./pyconfig.h
# done

# CC
# CFLAGS
# LDFLAGS
# LIBS
# CPPFLAGS
# CPP
# PKG_CONFIG
# PKG_CONFIG_PATH
# PKG_CONFIG_LIBDIR

# Build the framework
# make --debug=i
# make --debug frameworkinstallframework
make frameworkinstallstructure inclinstall

# # Clean after us
# git clean -fdxq
# git reset --hard HEAD

# Copy module map
cd '..'
mkdir "${DIST_DIR}/${PLATFORM}/${FRAMEWORK_NAME}.framework/Modules"
cp "./modulemaps/${FRAMEWORK_NAME}.modulemap" \
    "${DIST_DIR}/${PLATFORM}/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# Replace framework name in module map
# sed -i '' -E "s/__FRAMEWORK_NAME__/${FRAMEWORK_NAME}/g" \
#     "${DIST_DIR}/${PLATFORM}/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# "Verify"
test -x "${DIST_DIR}/${PLATFORM}/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" \
    && printf 'Build successfull!\n\n' \
    || printf 'Something went wrong.\n\n'