#!/bin/bash
set -e

# ===============================
# CONFIG
# ===============================
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_DIR="$(dirname "$0")"
ZXING_DIR="$REPO_ROOT/zxing-cpp"
ROOT_BUILD_DIR="$REPO_ROOT/artifacts/build"

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
#   ./build_zxing.sh macos x86_64
#   ./build_zxing.sh macos arm64
#   ./build_zxing.sh macos all    (builds both x86_64 and arm64)
#   ./build_zxing.sh windows x64          # Run on Windows machine with Visual Studio
#   ./build_zxing.sh linux x64

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
  echo "  ./build_zxing.sh macos x86_64         # Intel"
  echo "  ./build_zxing.sh macos arm64          # Apple Silicon"
  echo "  ./build_zxing.sh macos all            # Both Intel and Apple Silicon"
  echo "  ./build_zxing.sh windows x64          # 64-bit Windows"
  echo "  ./build_zxing.sh linux x64            # 64-bit Linux"
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

# Handle "all" for macOS - build both architectures
if [[ "$PLATFORM" == "macos" && "$ARCH" == "all" ]]; then
  echo "Building ZXing for all macOS architectures (Intel and Apple Silicon)..."
  bash "$SCRIPT_PATH" macos x86_64
  bash "$SCRIPT_PATH" macos arm64
  echo "✅ All macOS ZXing builds completed"
  exit 0
fi

BUILD_DIR=$ROOT_BUILD_DIR/zxing-$PLATFORM-$ARCH

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    CPU_COUNT=$NUMBER_OF_PROCESSORS
else
    CPU_COUNT=$(sysctl -n hw.ncpu)
fi

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
# macOS
# ===============================
if [[ "$PLATFORM" == "macos" ]]; then
  echo "Building ZXing for macOS: $ARCH"

  cmake "$ZXING_DIR" \
    -DCMAKE_OSX_ARCHITECTURES=$ARCH \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 \
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
# Windows
# ===============================
if [[ "$PLATFORM" == "windows" ]]; then
  echo "Building ZXing for Windows: $ARCH"

  # Native Windows build using MSVC (run on Windows machine)
  cmake "$ZXING_DIR" \
    -G "Visual Studio 17 2022" \
    -A x64 \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DZXING_EXAMPLES=OFF \
    -DZXING_BLACKBOX_TESTS=OFF \
    -DZXING_UNIT_TESTS=OFF \
    -DZXING_WRITERS=OFF \
    -DZXING_C_API=OFF

  cmake --build . --config Release
fi

# ===============================
# Linux
# ===============================
if [[ "$PLATFORM" == "linux" ]]; then
  echo "Building ZXing for Linux: $ARCH"

  # Assuming cross-compilation to Linux
  cmake "$ZXING_DIR" \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++ \
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
ARTIFACTS_DIST="$REPO_ROOT/artifacts/dist/zxing"
DIST_LIBS_DIR="$ARTIFACTS_DIST/$PLATFORM-$ARCH"

if [[ -d "$DIST_LIBS_DIR" ]]; then
  echo "Removing existing $DIST_LIBS_DIR"
  rm -rf "$DIST_LIBS_DIR"
fi

mkdir -p "$DIST_LIBS_DIR"

echo "📦 Moving ZXing build to artifacts dist directory..."

# Copy library
echo "  Copying library for $PLATFORM-$ARCH..."
if [[ "$PLATFORM" == "windows" ]]; then
  # MSVC produces .lib (import) and .dll files for shared libraries
  cp core/Release/ZXing.lib "$DIST_LIBS_DIR/"
  cp core/Release/ZXing.dll "$DIST_LIBS_DIR/"
else
  # GCC/MinGW produces .a files for static libraries
  cp core/libZXing.a "$DIST_LIBS_DIR/"
fi

echo "✅ ZXing build completed:"
echo "📂 Libs: $DIST_LIBS_DIR"

# Create ZIP
ZIP_NAME="zxing-$PLATFORM-$ARCH.zip"
echo "📦 Creating $ZIP_NAME..."
cd "$ARTIFACTS_DIST"
if [[ -f "$ZIP_NAME" ]]; then
  echo "Removing existing $ZIP_NAME"
  rm -f "$ZIP_NAME"
fi

zip -r "$ZIP_NAME" "$PLATFORM-$ARCH"
echo "✅ Created $ARTIFACTS_DIST/$ZIP_NAME"
