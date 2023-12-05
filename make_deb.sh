#!/usr/bin/bash

echo "make deb package for AO ..."
echo "- by mxchip@$(date)"

# build
BUILD_TYPE=$1
BUILD_DIR="./build"

set -eu

if [ -d "${BUILD_DIR}" ]; then
    rm -rf ${BUILD_DIR}
fi
mkdir -p ${BUILD_DIR}

cd ${BUILD_DIR}
if [ "${BUILD_TYPE}" == "debug" ]; then
    echo "build debug ..."
    cmake -DDEBUG=ON -DNNG_ENABLE_TLS=ON -DCONFIG_MXCHIP_DEBUG=1 ..
else
    echo "build release ..."
    cmake -DDEBUG=ON -DNNG_ENABLE_TLS=ON ..
fi

CPU_NUM=`cat /proc/stat |grep cpu[0-9] -c`
echo "make -j${CPU_NUM}"
make -j${CPU_NUM}

# packing script
echo "pack prepare ..."
arch="armhf"
build_type="-full"
package_type="deb"

pkg_name="nanomq-$(git describe --abbrev=0 --tags)-linux-${arch}${build_type}.${package_type}"

# no used for mxchip
: << EOF
make_flags="-DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ -DNNG_ENABLE_TLS=ON"
make_flags+=" -DNNG_ENABLE_SQLITE=ON "

make_flags+=" -DNNG_ENABLE_QUIC=ON "
make_flags+=" -DNNG_ENABLE_SQLITE=ON "
make_flags+=" -DQUIC_BUILD_SHARED=OFF "
make_flags+=" -DONEBRANCH=1 "
make_flags+=" -DCMAKE_CROSSCOMPILING=ON "
make_flags+=" -DCMAKE_PREFIX_PATH=/usr/arm-linux-gnueabihf "
if [ "$arch" == "arm64" ]; then
     make_flags+=" -DCMAKE_TARGET_ARCHITECTURE=arm64 "
     make_flags+=" -DGNU_MACHINE=aarch64-linux-gnu "
     make_flags+=" toolchains $PWD/nng/extern/msquic/cmake/toolchains/aarch64-linux.cmake "
elif [ "$arch" == "armhf" ]; then
     make_flags+=" -DCMAKE_TARGET_ARCHITECTURE=arm "
     make_flags+=" toolchains $PWD/nng/extern/msquic/cmake/toolchains/arm-linux.cmake "
     make_flags+=" -DGNU_MACHINE=arm-linux-gnueabihf "
fi

make_flags+=" -DENABLE_MYSQL=ON "
make_flags+=" -DENABLE_RULE_ENGINE=ON "
make_flags+=" -DENABLE_JWT=ON "
make_flags+=" -DBUILD_ZMQ_GATEWAY=ON "
make_flags+=" -DBUILD_BENCH=ON "
EOF

echo "start packing ..."
#set -eu
#cd build
mkdir -p _packages
sudo checkinstall --backup=no --install=no --type=debian --arch=${arch} --pkgname=nanomq --pkgversion=$(git describe --abbrev=0 --tags) --pkggroup=EMQX --maintainer=EMQX --provides=EMQX --pakdir _packages --recommends=1 --suggests=1 -y
sudo mv _packages/nanomq_$(git describe --abbrev=0 --tags)-1_${arch}.deb _packages/${pkg_name}
cd _packages; echo $(sha256sum ${pkg_name} | awk '{print $1}') > ${pkg_name}.sha256

echo "Success!"

