#!/bin/sh

set -eo pipefail

# PYTHON_VERSION='3.7'

# ==============================================================================

# Create framework output dir
mkdir -p "./build/macOS"

# Create executables dir to prevent installing them into the system
mkdir -p "./executables"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# FRAMEWORK_NAME='Python'$(echo $PYTHON_VERSION | sed 's/\./_/g')
FRAMEWORK_NAME='Python3_7'

# Make sure openssl is installed
brew install openssl

# Make sure wa have a clean cpython
git submodule update --init --recursive
cd './cpython'
git clean -fdxq
git checkout 3.7

# Set up for framework building
./configure \
    --enable-ipv6 \
    --with-pydebug \
    --with-openssl=$(brew --prefix openssl) \
    --enable-framework="${SCRIPT_DIR}/build/macOS" \
    --with-framework-name="${FRAMEWORK_NAME}" \
    --prefix="${SCRIPT_DIR}/executables"

# Build the framework
make
make frameworkinstall

# Copy module map
cd '..'
mkdir "./build/macOS/${FRAMEWORK_NAME}.framework/Modules"
cp "./modulemaps/${FRAMEWORK_NAME}.modulemap" \
    "./build/macOS/${FRAMEWORK_NAME}.framework/Modules/module.modulemap"

# Remove build files
git clean -fdxq

# Remove executables dir
rm -rf "./executables"