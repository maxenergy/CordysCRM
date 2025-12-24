# CordysCRM Flutter

A cross-platform CRM application built with Flutter, supporting mobile (Android/iOS) and desktop (Windows/macOS/Linux) platforms.

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Fully Supported | All features available |
| iOS | ✅ Fully Supported | All features available |
| Windows | ✅ Fully Supported | Desktop-optimized UI |
| macOS | ✅ Fully Supported | Desktop-optimized UI |
| Linux | ✅ Fully Supported | Desktop-optimized UI |

## Prerequisites

### Mobile Development
- Flutter SDK 3.0+
- Android Studio (for Android)
- Xcode (for iOS, macOS only)

### Desktop Development

**Windows:**
- Visual Studio 2022 or later with "Desktop development with C++" workload
- Windows 10 or later

**macOS:**
- Xcode 13 or later
- macOS 10.14 or later
- CocoaPods

**Linux:**
- Clang
- CMake
- GTK development headers
- Ninja-build

Install Linux dependencies:
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev
```

## Getting Started

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Running the Application

**Mobile:**
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios
```

**Desktop:**
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### 3. Building for Production

**Mobile:**
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

**Desktop:**
```bash
# Windows
flutter build windows --release

# macOS
flutter build macos --release

# Linux
flutter build linux --release
```

Build outputs:
- Windows: `build/windows/runner/Release/`
- macOS: `build/macos/Build/Products/Release/`
- Linux: `build/linux/x64/release/bundle/`

## Platform-Specific Features

### Desktop Features
- **Responsive Layout**: Automatically switches between mobile and desktop UI based on window size
  - Desktop (≥600px width): NavigationRail sidebar
  - Mobile (<600px width): BottomNavigationBar
- **Window Management**: Persistent window size and position
- **Keyboard Shortcuts**: Common shortcuts for navigation and actions
- **File Picker**: Native file selection dialogs
- **Performance Optimizations**: Higher pagination limits and image cache

### Mobile-Only Features
The following features are only available on mobile platforms:
- **Camera Access**: Direct camera capture for photos
- **Voice Recording**: Audio recording for follow-up notes
- **WebView**: Enterprise search with in-app browser (爱企查/企查查)

On desktop, these features show appropriate disabled states or alternative options.

## Desktop UI Behavior

### Window Constraints
- **Default Size**: 1200x800
- **Minimum Size**: 800x600
- **Window State**: Position and size are automatically saved and restored

### Responsive Breakpoints
- **Width ≥ 600px**: Desktop layout with NavigationRail
- **Width < 600px**: Mobile layout with BottomNavigationBar

### Keyboard Shortcuts (Planned)
- `Ctrl+N`: New item
- `Ctrl+S`: Save
- `Ctrl+F`: Search
- `Ctrl+R`: Refresh

## Database Storage

The app uses Drift for local database storage with platform-specific paths:

- **Mobile**: `ApplicationDocumentsDirectory`
- **Desktop**: `ApplicationSupportDirectory`

Database files are automatically created on first launch.

## Development

### Code Analysis
```bash
flutter analyze
```

### Running Tests
```bash
flutter test
```

### Property-Based Tests
```bash
flutter test test/property_tests/
```

## Known Limitations

### Desktop Limitations
1. **WebView Not Supported**: Enterprise search with WebView (爱企查/企查查) is not available on desktop due to `flutter_inappwebview` limitations. Users should use the web version for this feature.
2. **No Camera Access**: Desktop platforms don't have camera support. Use file picker to select images instead.
3. **No Voice Recording**: Audio recording is not available on desktop.

### Workarounds
- For enterprise search: Use the web application
- For images: Use the file picker to select existing images
- For audio notes: Use text notes instead

## Troubleshooting

### Windows Build Issues
- Ensure Visual Studio 2022 is installed with C++ desktop development workload
- Run `flutter doctor` to verify setup

### macOS Build Issues
- Ensure Xcode command line tools are installed: `xcode-select --install`
- Run `pod install` in the `macos/` directory if needed

### Linux Build Issues
- Verify all dependencies are installed: `flutter doctor`
- Check GTK version: `pkg-config --modversion gtk+-3.0`

## Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── services/        # Platform services, window management
│   └── utils/           # Utilities, adaptive file picker
├── data/                # Data layer (repositories, data sources)
├── domain/              # Domain layer (entities, use cases)
└── presentation/        # UI layer (pages, widgets, providers)
    ├── features/        # Feature-specific pages
    ├── widgets/         # Reusable widgets
    └── theme/           # Theme configuration
```

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Desktop Support](https://docs.flutter.dev/desktop)
- [Drift Database](https://drift.simonbinder.eu/)
- [Riverpod State Management](https://riverpod.dev/)

## License

See LICENSE file for details.
