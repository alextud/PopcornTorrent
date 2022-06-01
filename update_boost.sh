#!/bin/bash

BOOST_TARBALL="boost.tar.gz"

DIR=`pwd`
HEADERS_DIR="${DIR}/include/boost"
BUILD_DIR="${DIR}/build_dependecies/boost"

clean() {
    rm ${BOOST_TARBALL}
}

download() {
    curl -L -o ${BOOST_TARBALL} \
        "https://boostorg.jfrog.io/artifactory/main/release/1.79.0/source/boost_1_79_0.tar.gz"
}

extract() {
    rm -rf ${BUILD_DIR} && mkdir -p ${BUILD_DIR}
    tar -xzf ${BOOST_TARBALL} --strip 1 -C ${BUILD_DIR}
    
    rm -rf ${HEADERS_DIR} && mkdir -p ${HEADERS_DIR}
    cp -r "${BUILD_DIR}/boost" "${DIR}/include"
}

clean
download
extract

echo "Done."

