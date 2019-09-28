#!/bin/sh

set -eo pipefail

PYTHON_VERSION='3.7'


# ==============================================================================
#   Do not edit below this line!
# ==============================================================================


SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
FRAMEWORK_NAME='Python'$(echo $PYTHON_VERSION | sed 's/\./_/g')

# Make sure openssl is installed
if brew list openssl 2>/dev/null >/dev/null; then
    printf 'OpenSSL via Homebrew found.\n'
else
    printf 'OpenSSL via Homebrew is required. Installing OpenSSL...\n'
    brew install openssl
fi

# Make sure the framework output dir exists, but the framework not
mkdir -p "./build/macOS"
rm -rf "./build/macOS/${FRAMEWORK_NAME}.framework"

# Make sure wa have a clean cpython
git submodule update --init --recursive
cd './cpython'
git clean -fdxq
git reset --hard HEAD
git checkout "${PYTHON_VERSION}"

# Force building the framework only (no apps or unixtools)
sed -i '' -E \
    's/(FRAMEWORK(ALT)?INSTALLLAST=)".+"/\1"frameworkinstallframework"/g' \
    ./configure*

# Set up for framework building
./configure \
    --enable-ipv6 \
    --with-pydebug \
    --without-ensurepip \
    --with-openssl=$(brew --prefix openssl) \
    --enable-framework="${SCRIPT_DIR}/build/macOS" \
    --with-framework-name="${FRAMEWORK_NAME}" \
    --prefix="${SCRIPT_DIR}/build/dummy"

# Build the framework
make
make frameworkinstallframework

# Clean after us
git clean -fdxq
git reset --hard HEAD

# Copy module map
cd '..'
mkdir "./build/macOS/${FRAMEWORK_NAME}.framework/Modules"
cp "./modulemaps/${FRAMEWORK_NAME}.modulemap" \
    "./build/macOS/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# Replace framework name in module map
# sed -i '' -E "s/__FRAMEWORK_NAME__/${FRAMEWORK_NAME}/g" \
#     "./build/macOS/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# "Verify"
test -x "./build/macOS/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME}" \
    && printf 'Build successfull!\n\n' \
    || printf 'Something went wrong.\n\n'