#!/bin/bash
set -e

# ===============================
# CONFIG
# ===============================
REPO_ROOT="$(pwd)"
SCRIPT_DIR="$(pwd)/scripts"
ZXING_DIR="$REPO_ROOT/zxing-cpp"
ROOT_BUILD_DIR="$(pwd)/build"

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

# NDK path (must be set in environment)
ANDROID_NDK_HOME="$ANDROID_NDK_HOME"

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
  if [[ -z "$ANDROID_NDK_HOME" ]]; then
    echo "Error: ANDROID_NDK_HOME environment variable must be set for Android builds"
    exit 1
  elif [[ ! -d "$ANDROID_NDK_HOME" ]]; then
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
# MOVE TO ARTIFACTS DIST DIRECTORY
# ===============================
ARTIFACTS_DIST="$REPO_ROOT/dist"
DIST_LIBS_DIR="$ARTIFACTS_DIST/$PLATFORM-$ARCH"

mkdir -p "$DIST_LIBS_DIR"

echo "📦 Moving ZXing build to artifacts dist directory..."

# Copy library
echo "  Copying library for $PLATFORM-$ARCH..."
cp core/libZXing.a "$DIST_LIBS_DIR/"

echo "✅ ZXing build completed:"
echo "📂 Libs: $DIST_LIBS_DIR"

# Create ZIP
ZIP_NAME="zxing-$PLATFORM-$ARCH.zip"
echo "📦 Creating $ZIP_NAME..."
cd "$ARTIFACTS_DIST"
zip -r "$ZIP_NAME" "$PLATFORM-$ARCH"
echo "✅ Created $ARTIFACTS_DIST/$ZIP_NAME"
