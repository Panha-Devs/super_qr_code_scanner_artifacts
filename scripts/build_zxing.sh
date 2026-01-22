#!/bin/bash
set -e

# ===============================
# CONFIG
# ===============================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ZXING_DIR="$REPO_ROOT/zxing-cpp"
ROOT_BUILD_DIR="$REPO_ROOT/custom_build/build"

# ===============================
# ARGUMENTS
# ===============================
# Usage:
#   ./build_zxing.sh android arm64-v8a
#   ./build_zxing.sh android armeabi-v7a
#   ./build_zxing.sh android all  (builds both 32-bit and 64-bit)
#   ./build_zxing.sh ios arm64
#   ./build_zxing.sh ios x86_64
#   ./build_zxing.sh ios all      (builds both device and simulator)

PLATFORM=$1
ARCH=$2

# Default NDK path
ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-/Users/vtech/Library/Android/sdk/ndk/28.2.13676358}"

if [[ -z "$PLATFORM" || -z "$ARCH" ]]; then
  echo "Usage:"
  echo "  ./build_zxing.sh android arm64-v8a    # 64-bit"
  echo "  ./build_zxing.sh android armeabi-v7a  # 32-bit"
  echo "  ./build_zxing.sh android all          # Both 32-bit and 64-bit"
  echo "  ./build_zxing.sh ios arm64            # Device"
  echo "  ./build_zxing.sh ios x86_64           # Simulator"
  echo "  ./build_zxing.sh ios all              # Both device and simulator"
  exit 1
fi

# Get script directory for recursive calls
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Handle "all" for Android - build both ABIs
if [[ "$PLATFORM" == "android" && "$ARCH" == "all" ]]; then
  echo "Building ZXing for all Android ABIs (32-bit and 64-bit)..."
  bash "$SCRIPT_PATH" android armeabi-v7a
  bash "$SCRIPT_PATH" android arm64-v8a
  echo "✅ All Android ZXing builds completed"
  exit 0
fi

# Handle "all" for iOS - build both device and simulator
if [[ "$PLATFORM" == "ios" && "$ARCH" == "all" ]]; then
  echo "Building ZXing for all iOS architectures (device and simulator)..."
  bash "$SCRIPT_PATH" ios arm64
  bash "$SCRIPT_PATH" ios x86_64
  echo "✅ All iOS ZXing builds completed"
  exit 0
fi

BUILD_DIR=$ROOT_BUILD_DIR/zxing-$PLATFORM-$ARCH

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

CPU_COUNT=$(sysctl -n hw.ncpu)

# ===============================
# ANDROID
# ===============================
if [[ "$PLATFORM" == "android" ]]; then
  if [[ ! -d "$ANDROID_NDK_HOME" ]]; then
    echo "Error: Android NDK not found at $ANDROID_NDK_HOME"
    exit 1
  fi
  
  echo "Using NDK: $ANDROID_NDK_HOME"
  echo "Building ZXing for ABI: $ARCH"

  cmake "$ZXING_DIR" \
    -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
    -DANDROID_ABI=$ARCH \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DZXING_EXAMPLES=OFF \
    -DZXING_BLACKBOX_TESTS=OFF \
    -DZXING_UNIT_TESTS=OFF \
    -DZXING_WRITERS=OFF \
    -DZXING_C_API=OFF \
    -DCMAKE_C_FLAGS_RELEASE="-O3 -ffunction-sections -fdata-sections" \
    -DCMAKE_CXX_FLAGS_RELEASE="-O3 -ffunction-sections -fdata-sections"

  cmake --build . -j$CPU_COUNT
fi

# ===============================
# iOS
# ===============================
if [[ "$PLATFORM" == "ios" ]]; then
  echo "Building ZXing for iOS: $ARCH"
  
  if [[ "$ARCH" == "x86_64" || "$ARCH" == "arm64;x86_64" ]]; then
    SDK="iphonesimulator"
  else
    SDK="iphoneos"
  fi

  cmake "$ZXING_DIR" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=$ARCH \
    -DCMAKE_OSX_SYSROOT=$(xcrun --sdk $SDK --show-sdk-path) \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DZXING_EXAMPLES=OFF \
    -DZXING_BLACKBOX_TESTS=OFF \
    -DZXING_UNIT_TESTS=OFF \
    -DZXING_WRITERS=OFF \
    -DZXING_C_API=OFF \
    -DCMAKE_CXX_FLAGS_RELEASE="-O3 -ffunction-sections"

  cmake --build . -j$CPU_COUNT
fi

# ===============================
# MOVE TO PLUGIN DIRECTORY
# ===============================
PLUGIN_ZXING_BASE="/Users/vtech/CodeWorkspaces/C++/qr_code_scanner/flutter_plugin/super_qr_code_scanner/src/zxing"
PLUGIN_INCLUDE_DIR="$PLUGIN_ZXING_BASE/include"
PLUGIN_LIBS_DIR="$PLUGIN_ZXING_BASE/libs/$PLATFORM-$ARCH"

mkdir -p "$PLUGIN_LIBS_DIR"

echo "📦 Moving ZXing build to plugin directory..."

# Copy headers (only once, they're platform-independent)
if [[ ! -d "$PLUGIN_INCLUDE_DIR" ]]; then
  echo "  Copying headers..."
  mkdir -p "$PLUGIN_INCLUDE_DIR"
  # Copy only .h header files, preserving directory structure
  cd "$ZXING_DIR/core/src"
  find . -name "*.h" -exec rsync -R {} "$PLUGIN_INCLUDE_DIR/" \;
  cd "$BUILD_DIR"
else
  echo "  Headers already exist, skipping..."
fi

# Copy library
echo "  Copying library for $PLATFORM-$ARCH..."
rm -rf "$PLUGIN_LIBS_DIR"
mkdir -p "$PLUGIN_LIBS_DIR"
cp core/libZXing.a "$PLUGIN_LIBS_DIR/"

echo "✅ ZXing build completed:"
echo "📂 Headers: $PLUGIN_INCLUDE_DIR"
echo "📂 Libs: $PLUGIN_LIBS_DIR"
