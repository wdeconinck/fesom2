#!/usr/bin/env bash

set -e
HERE=$PWD
source env.sh # source this from your run script too
mkdir -p build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HERE ${CMAKE_ARGS}
make install -j`nproc --all`
