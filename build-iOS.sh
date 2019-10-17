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
if brew list openssl 2>/dev/null >/dev/null; then
    printf 'OpenSSL via Homebrew found.\n'
else
    printf 'OpenSSL via Homebrew is required. Installing OpenSSL...\n'
    brew install openssl
fi

# Make sure the framework output dir exists, but the framework not
mkdir -p "./build/${PLATFORM}"
rm -rf "./build/${PLATFORM}/${FRAMEWORK_NAME}.framework"

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
    --with-openssl=$(brew --prefix openssl) \
    --enable-framework="${SCRIPT_DIR}/build/${PLATFORM}" \
    --with-framework-name="${FRAMEWORK_NAME}" \
    --prefix="${SCRIPT_DIR}/build/dummy" \
    ac_cv_file__dev_ptmx=no \
    ac_cv_file__dev_ptc=no
    # ac_cv_func_
    # --without-doc-strings \

# FIXME: No getentropy on iOS
sed -i '' -E "s/.*HAVE_GETENTROPY.*/\/\* #undef HAVE_GETENTROPY \*\//g" ./pyconfig.h

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
make
make frameworkinstallframework

exit 0

# Clean after us
git clean -fdxq
git reset --hard HEAD

# Copy module map
cd '..'
mkdir "./build/${PLATFORM}/${FRAMEWORK_NAME}.framework/Modules"
cp "./modulemaps/${FRAMEWORK_NAME}.modulemap" \
    "./build/${PLATFORM}/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# Replace framework name in module map
# sed -i '' -E "s/__FRAMEWORK_NAME__/${FRAMEWORK_NAME}/g" \
#     "./build/${PLATFORM}/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# "Verify"
test -x "./build/${PLATFORM}/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" \
    && printf 'Build successfull!\n\n' \
    || printf 'Something went wrong.\n\n'