#!/bin/bash
set -e

# =========================
# CONFIG
# =========================
OPENCV_VERSION=4.13.0
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT_DIR="$(dirname "$0")"
OPENCV_DIR="$REPO_ROOT/opencv"
ROOT_BUILD_DIR="$REPO_ROOT/artifacts/build"

# =========================
# ARGUMENTS
# =========================
# Usage:
#   ./build_opencv.sh android arm64-v8a
#   ./build_opencv.sh android armeabi-v7a
#   ./build_opencv.sh android all  (builds both 32-bit and 64-bit)
#   ./build_opencv.sh ios arm64
#   ./build_opencv.sh ios x86_64
#   ./build_opencv.sh ios all              # Both device and simulator
#   ./build_opencv.sh macos x86_64
#   ./build_opencv.sh macos arm64
#   ./build_opencv.sh macos all            # Both x86_64 and arm64
#   ./build_opencv.sh windows x64
#   ./build_opencv.sh linux x64

PLATFORM=$1
ARCH=$2

# NDK path (must be set in environment)
ANDROID_NDK_HOME="$ANDROID_NDK_HOME"

if [[ -z "$PLATFORM" || -z "$ARCH" ]]; then
  echo "Usage:"
  echo "  ./build_opencv.sh android arm64-v8a    # 64-bit"
  echo "  ./build_opencv.sh android armeabi-v7a  # 32-bit"
  echo "  ./build_opencv.sh android all          # Both 32-bit and 64-bit"
  echo "  ./build_opencv.sh ios arm64            # Device"
  echo "  ./build_opencv.sh ios x86_64           # Simulator"
  echo "  ./build_opencv.sh ios all              # Both device and simulator"
  echo "  ./build_opencv.sh macos x86_64         # Intel"
  echo "  ./build_opencv.sh macos arm64          # Apple Silicon"
  echo "  ./build_opencv.sh macos all            # Both Intel and Apple Silicon"
  echo "  ./build_opencv.sh windows x64          # 64-bit Windows"
  echo "  ./build_opencv.sh linux x64            # 64-bit Linux"
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

# Handle "all" for macOS - build both architectures
if [[ "$PLATFORM" == "macos" && "$ARCH" == "all" ]]; then
  echo "Building for all macOS architectures (Intel and Apple Silicon)..."
  bash "$SCRIPT_PATH" macos x86_64
  bash "$SCRIPT_PATH" macos arm64
  echo "✅ All macOS builds completed"
  exit 0
fi

BUILD_DIR=$ROOT_BUILD_DIR/$PLATFORM-$ARCH
INSTALL_DIR=$BUILD_DIR/install

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# =========================
# SHARED LIBS CONFIG
# =========================
if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "macos" ]]; then
  BUILD_SHARED_LIBS="OFF"
else
  BUILD_SHARED_LIBS="ON"
fi

# =========================
# COMMON OPTIONS
# =========================
COMMON_CMAKE_OPTIONS="
-DCMAKE_BUILD_TYPE=Release
-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
-DBUILD_LIST=core,imgproc,imgcodecs
-DBUILD_SHARED_LIBS=$BUILD_SHARED_LIBS
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
-DWITH_WEBP=OFF
-DWITH_OPENEXR=OFF
-DWITH_JASPER=OFF
-DWITH_OPENJPEG=OFF
"

# =========================
# ANDROID
# =========================
if [[ "$PLATFORM" == "android" ]]; then
  if [[ -z "$ANDROID_NDK_HOME" ]]; then
    echo "Error: ANDROID_NDK_HOME environment variable must be set for Android builds"
    exit 1
  elif [[ ! -d "$ANDROID_NDK_HOME" ]]; then
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
  if [[ "$ARCH" == "x86_64" ]]; then
    SDK="iphonesimulator"
  else
    SDK="iphoneos"
  fi

  cmake $OPENCV_DIR \
    -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=$ARCH \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_OSX_SYSROOT=$(xcrun --sdk $SDK --show-sdk-path) \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="-" \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_SHARED_LINKER_FLAGS="-framework CoreGraphics" \
    $COMMON_CMAKE_OPTIONS

  cmake --build . --config Release
  cmake --install .
fi

# =========================
# macOS
# =========================
if [[ "$PLATFORM" == "macos" ]]; then
  echo "Building for macOS: $ARCH"
  
  cmake $OPENCV_DIR \
    -DCMAKE_OSX_ARCHITECTURES=$ARCH \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=10.15 \
    -DWITH_KLEIDICV=OFF \
    -DWITH_OPENEXR=OFF \
    $COMMON_CMAKE_OPTIONS

  cmake --build . --target install -j$(sysctl -n hw.ncpu)
fi

# =========================
# Windows
# =========================
if [[ "$PLATFORM" == "windows" ]]; then
  echo "Building for Windows: $ARCH"
  
  # Assuming cross-compilation with MinGW (requires mingw-w64 installed)
  cmake $OPENCV_DIR \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ \
    $COMMON_CMAKE_OPTIONS

  cmake --build . --target install -j$(sysctl -n hw.ncpu)
fi

# =========================
# Linux
# =========================
if [[ "$PLATFORM" == "linux" ]]; then
  echo "Building for Linux: $ARCH"
  
  # Assuming cross-compilation to Linux (requires appropriate toolchain)
  cmake $OPENCV_DIR \
    -DCMAKE_SYSTEM_NAME=Linux \
    -DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc \
    -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++ \
    $COMMON_CMAKE_OPTIONS

  cmake --build . --target install -j$(sysctl -n hw.ncpu)
fi

# =========================
# MOVE TO ARTIFACTS DIST DIRECTORY
# =========================
ARTIFACTS_DIST="$REPO_ROOT/artifacts/dist/opencv"
DIST_LIBS_DIR="$ARTIFACTS_DIST/$PLATFORM-$ARCH"

if [[ -d "$DIST_LIBS_DIR" ]]; then
  echo "  Remove existing files in $DIST_LIBS_DIR..."
  rm -rf "$DIST_LIBS_DIR"
fi

mkdir -p "$DIST_LIBS_DIR"

echo "📦 Moving build to artifacts dist directory..."

# Determine source paths based on platform
if [[ "$PLATFORM" == "android" ]]; then
  SOURCE_LIB_DIR="$INSTALL_DIR/sdk/native/libs/$ARCH"
else
  SOURCE_LIB_DIR="$INSTALL_DIR/lib"
fi

# Copy libraries to dist/{platform-abi}/
echo "  Copying libraries for $PLATFORM-$ARCH..."
if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "macos" ]]; then
  # For iOS and macOS, copy static libraries (.a files)
  for lib in core imgproc imgcodecs; do
    cp "$SOURCE_LIB_DIR/libopencv_$lib.a" "$DIST_LIBS_DIR/libopencv_$lib.a"
  done
  # Copy 3rdparty dependencies
  cp "$INSTALL_DIR/lib/opencv4/3rdparty/"*.a "$DIST_LIBS_DIR/"
else
  cp -r "$SOURCE_LIB_DIR"/* "$DIST_LIBS_DIR/"
fi

echo "✅ OpenCV build completed:"
echo "📂 Libs: $DIST_LIBS_DIR"

# Create ZIP
ZIP_NAME="opencv-$PLATFORM-$ARCH.zip"
echo "📦 Creating $ZIP_NAME..."
cd "$ARTIFACTS_DIST"
if [[ -f "$ZIP_NAME" ]]; then
  echo "Removing existing $ZIP_NAME"
  rm -f "$ZIP_NAME"
fi
zip -r "$ZIP_NAME" "$PLATFORM-$ARCH"
echo "✅ Created $ARTIFACTS_DIST/$ZIP_NAME"
