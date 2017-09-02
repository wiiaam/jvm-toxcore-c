#!/bin/bash



cd /sources

mkdir artifacts

echo "Building for arch: $1"

if [[ $1 == "armel" ]]; then
  ARCH="arm"
  API="14"
  export TARGET="arm-linux-androideabi"
elif [[ $1 == "arm64" ]]; then
  ARCH="arm64"
  API="21"
  export TARGET="aarch64-linux-android"
elif [[ $1 == "x86-64" ]]; then
  ARCH="x86_64"
  API="21"
  export TARGET="x86_64-linux-android"
elif [[ $1  == "x86" ]]; then
  ARCH="x86"
  API="14"
  export TARGET="i686-linux-android"
else
  echo "Error: Unsupported Android architecture!"
  echo "Supported architectures: armel arm64 x86-64 x86"
  exit 1
fi

cd /sources
mkdir toxcore
mkdir protobuf
mkdir protobuf_native

wget https://build.tox.chat/job/libtoxcore-toktok_build_android_$1_static_release/lastSuccessfulBuild/artifact/libtoxcore-toktok_build_android_$1_static_release.tar.xz -P /sources/toxcore

wget https://build.tox.chat/job/protobuf_build_android_$1_release/lastSuccessfulBuild/artifact/protobuf.tar.xz -P /sources/protobuf

wget https://build.tox.chat/job/protobuf_build_android_$1_release/lastSuccessfulBuild/artifact/protobuf_native.tar.xz -P /sources/protobuf_native


echo "Extracting downloaded dependenceies"
# Untar dependencies
cd toxcore
tar -xf libtoxcore*.tar.xz
cd ../protobuf
tar -xf protobuf.tar.xz
cd ../protobuf_native
tar -xf protobuf_native.tar.xz
export PATH="${PWD}/bin:$PATH"
cd ../tox4j

# Export stuff
export ANDROID_NDK_HOME=/opt/android-ndk
export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64/
export PATH="$JAVA_HOME/bin:$PATH"

# Create toolchain
mkdir -p toolchains/$TARGET
export TOOLCHAIN=$(pwd)/toolchains/$TARGET
"$ANDROID_NDK_HOME/build/tools/make_standalone_toolchain.py" --arch ${ARCH} --api ${API} --install-dir "$TOOLCHAIN" --force
export PATH="$TOOLCHAIN/bin:$PATH"

# Fix pkg-config
for file in ../toxcore/lib/pkgconfig/*.pc; do
  sed -i "/^prefix=/s|.*|prefix=$TOOLCHAIN/sysroot/usr/|" $file
  sed -i "s|-lpthread||" $file
  cat $file
done
export PKG_CONFIG_PATH="$TOOLCHAIN/sysroot/usr/lib/pkgconfig"
# PKG_CONGIG_PATH seems to be overwritten by the build script, so we force it by
# using PKG_CONFIG_LIBDIR, which makes pkg-config totally ignore PKG_CONFIG_PATH
export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"
# move precompiled libs to the toolchain
cp -r ../toxcore/* $TOOLCHAIN/sysroot/usr/

# Don't create cache/repository directories in /home/jenkins (which triggers apparmor) but rather create them in the current directory
mkdir .ivy
mkdir .sbt
export SBT="sbt -Dsbt.ivy.home=$(pwd)/.ivy -Dsbt.boot.directory=$(pwd)/.sbt"
mkdir .m2
export MAVEN_OPTS="-Dmaven.repo.local=$(pwd)/.m2"

# Build!
export SBT="${SBT} -Dsbt.log.noformat=true"
buildscripts/04_build

# Copy artifacts
cp target/$TARGET/*.so $WORKSPACE/artifacts/
cp target/scala-2.11/*.jar $WORKSPACE/artifacts/

# Strip the .so to save space
$TARGET-strip -s $WORKSPACE/artifacts/*.so


bash
