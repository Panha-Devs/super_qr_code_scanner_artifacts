# Super QR Code Scanner - Native Libraries

This repository contains pre-built native libraries for the [Super QR Code Scanner](https://pub.dev/packages/super_qr_code_scanner) Flutter plugin.

## Overview

To keep the plugin package size small on pub.dev, native libraries (OpenCV and ZXing) are not bundled. Instead, they are hosted here as release assets and downloaded on-demand using the plugin's setup script.

## Library Structure

Each release contains ZIP files for different platforms and architectures:

- `opencv-{platform}-{abi}.zip` - OpenCV libraries
- `zxing-{platform}-{abi}.zip` - ZXing libraries

### Supported Platforms

| Platform | Architectures | Status |
|----------|---------------|--------|
| Android | arm64-v8a, armeabi-v7a | ✅ Available |
| iOS | arm64, x86_64 | 🚧 Planned |
| macOS | arm64, x86_64 | 🚧 Planned |
| Linux | x64 | 🚧 Planned |
| Windows | x64 | 🚧 Planned |

## For Plugin Users

If you're using the Super QR Code Scanner plugin, you don't need to interact with this repository directly. The plugin's setup script will automatically download the required libraries:

```bash
flutter pub run super_qr_code_scanner:setup
```

## For Plugin Maintainers

### Building Libraries

Libraries are built using CMake and stored in the `dist/` directory. The build scripts are located in the main plugin repository.

### Creating Releases

1. Build the libraries for target platforms
2. Create ZIP archives: `zip -r {lib}-{platform}-{abi}.zip {platform}-{abi}/`
3. Create a new GitHub release
4. Upload the ZIP files as release assets
5. Update the `releaseTag` in the plugin's `bin/setup.dart`

### Repository Structure

```
artifacts/
├── dist/           # Build outputs (ignored by git)
│   ├── *.zip       # Release assets (tracked)
│   └── ...         # Build directories (ignored)
├── scripts/        # Build scripts
├── .gitignore      # Ignores dist dirs but keeps ZIPs
└── README.md       # This file
```

## License

These libraries are part of the Super QR Code Scanner plugin and follow the same license terms.