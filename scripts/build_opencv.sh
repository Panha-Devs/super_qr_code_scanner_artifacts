#!/bin/bash
set -e

# =========================
# CONFIG
# =========================
OPENCV_VERSION=4.13.0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OPENCV_DIR="$REPO_ROOT/opencv"
ROOT_BUILD_DIR="$REPO_ROOT/custom_build/build"

# =========================
# ARGUMENTS
# =========================
# Usage:
#   ./build_opencv.sh android arm64-v8a
#   ./build_opencv.sh android armeabi-v7a
#   ./build_opencv.sh android all  (builds both 32-bit and 64-bit)
#   ./build_opencv.sh ios arm64

PLATFORM=$1
ARCH=$2

# Default NDK path
ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-/Users/vtech/Library/Android/sdk/ndk/28.2.13676358}"

if [[ -z "$PLATFORM" || -z "$ARCH" ]]; then
  echo "Usage:"
  echo "  ./build_opencv.sh android arm64-v8a    # 64-bit"
  echo "  ./build_opencv.sh android armeabi-v7a  # 32-bit"
  echo "  ./build_opencv.sh android all          # Both 32-bit and 64-bit"
  echo "  ./build_opencv.sh ios arm64            # Device"
  echo "  ./build_opencv.sh ios x86_64           # Simulator"
  echo "  ./build_opencv.sh ios all              # Both device and simulator"
  exit 1
fi

# Get script directory for recursive calls
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Handle "all" for Android - build both ABIs
if [[ "$PLATFORM" == "android" && "$ARCH" == "all" ]]; then
  echo "Building for all Android ABIs (32-bit and 64-bit)..."
  bash "$SCRIPT_PATH" android armeabi-v7a
  bash "$SCRIPT_PATH" android arm64-v8a
  echo "✅ All Android builds completed"
  exit 0
fi

# Handle "all" for iOS - build both device and simulator
if [[ "$PLATFORM" == "ios" && "$ARCH" == "all" ]]; then
  echo "Building for all iOS architectures (device and simulator)..."
  bash "$SCRIPT_PATH" ios arm64
  bash "$SCRIPT_PATH" ios x86_64
  echo "✅ All iOS builds completed"
  exit 0
fi

BUILD_DIR=$ROOT_BUILD_DIR/$PLATFORM-$ARCH
INSTALL_DIR=$BUILD_DIR/install

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# =========================
# COMMON OPTIONS
# =========================
COMMON_CMAKE_OPTIONS="
-DCMAKE_BUILD_TYPE=Release
-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
-DBUILD_LIST=core,imgproc,imgcodecs
-DBUILD_SHARED_LIBS=ON
-DBUILD_TESTS=OFF
-DBUILD_PERF_TESTS=OFF
-DBUILD_EXAMPLES=OFF
-DBUILD_opencv_apps=OFF
-DBUILD_opencv_video=OFF
-DBUILD_opencv_highgui=OFF
-DBUILD_opencv_dnn=OFF
-DBUILD_opencv_ml=OFF
-DBUILD_opencv_calib3d=OFF
-DBUILD_opencv_features2d=OFF
-DBUILD_opencv_flann=OFF
-DWITH_IPP=OFF
-DWITH_TBB=OFF
-DWITH_OPENCL=OFF
-DWITH_VULKAN=OFF
-DWITH_CUDA=OFF
"

# =========================
# ANDROID
# =========================
if [[ "$PLATFORM" == "android" ]]; then
  if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
    echo "Error: Android NDK not found at $ANDROID_NDK_HOME"
    exit 1
  fi
  
  echo "Using NDK: $ANDROID_NDK_HOME"
  echo "Building for ABI: $ARCH"

  cmake $OPENCV_DIR \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=$ARCH \
    -DANDROID_PLATFORM=android-24 \
    -DANDROID_STL=c++_shared \
    -DBUILD_ANDROID_PROJECTS=OFF \
    -DBUILD_ANDROID_EXAMPLES=OFF \
    -DBUILD_JAVA=OFF \
    $COMMON_CMAKE_OPTIONS

  cmake --build . --target install -j$(sysctl -n hw.ncpu)
fi

# =========================
# iOS
# =========================
if [[ "$PLATFORM" == "ios" ]]; then
  cmake $OPENCV_DIR \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=$ARCH \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    $COMMON_CMAKE_OPTIONS

  cmake --build . --config Release
  cmake --install .
fi

# =========================
# MOVE TO PLUGIN DIRECTORY
# =========================
PLUGIN_OPENCV_BASE="/Users/vtech/CodeWorkspaces/C++/qr_code_scanner/flutter_plugin/super_qr_code_scanner/src/opencv"
PLUGIN_INCLUDE_DIR="$PLUGIN_OPENCV_BASE/include"
PLUGIN_LIBS_DIR="$PLUGIN_OPENCV_BASE/libs/$PLATFORM-$ARCH"

mkdir -p "$PLUGIN_LIBS_DIR"

echo "📦 Moving build to plugin directory..."

# Determine source paths based on platform
if [[ "$PLATFORM" == "android" ]]; then
  SOURCE_INCLUDE_DIR="$INSTALL_DIR/sdk/native/jni/include"
  SOURCE_LIB_DIR="$INSTALL_DIR/sdk/native/libs/$ARCH"
else
  SOURCE_INCLUDE_DIR="$INSTALL_DIR/include"
  SOURCE_LIB_DIR="$INSTALL_DIR/lib"
fi

# Copy headers (only once, they're platform-independent)
if [[ ! -d "$PLUGIN_INCLUDE_DIR" ]]; then
  echo "  Copying headers..."
  cp -r "$SOURCE_INCLUDE_DIR" "$PLUGIN_INCLUDE_DIR"
else
  echo "  Headers already exist, skipping..."
fi

# Copy libraries to libs/{platform-abi}/
echo "  Copying libraries for $PLATFORM-$ARCH..."
rm -rf "$PLUGIN_LIBS_DIR"
cp -r "$SOURCE_LIB_DIR" "$PLUGIN_LIBS_DIR"

echo "✅ OpenCV build completed:"
echo "📂 Headers: $PLUGIN_INCLUDE_DIR"
echo "📂 Libs: $PLUGIN_LIBS_DIR"
