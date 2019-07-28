#!/bin/sh

set -eo pipefail

# Create framework output dir
mkdir -p "./build/macOS"

# Create intermediate (build) dir
mkdir -p "./intermediate"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


# Make sure cpython is here & switch to it
git submodule update --init --recursive
cd './cpython'

# Set up for framework building
./configure --enable-optimizations --enable-profiling=no --enable-ipv6 --enable-framework="${SCRIPT_DIR}/build/macOS" --prefix="${SCRIPT_DIR}/intermediate"

# Build the framework
make
make frameworkinstall

# Remove build files
git clean -fdxq