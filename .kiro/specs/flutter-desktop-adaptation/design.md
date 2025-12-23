# Design Document: Flutter Desktop Adaptation

## Overview

This design document outlines the approach for adapting the existing Flutter mobile CRM application to desktop platforms (Windows, macOS, Linux). The adaptation focuses on creating a responsive UI that automatically adjusts between mobile and desktop layouts while maintaining code reusability and platform-specific optimizations.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Application Layer                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Mobile UI  │  │ Responsive   │  │  Desktop UI  │  │
│  │  (< 600px)   │  │    Logic     │  │  (≥ 600px)   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────┐
│                  Platform Detection Layer                │
│         Platform.isAndroid / isIOS / isDesktop          │
└─────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────┐
│                   Business Logic Layer                   │
│     (Shared across all platforms - no changes)          │
│  Providers, Repositories, Services, Entities            │
└─────────────────────────────────────────────────────────┘
```

### Responsive Layout Strategy

The app will use a breakpoint-based responsive design:
- **Mobile Layout** (width < 600px): BottomNavigationBar
- **Desktop Layout** (width ≥ 600px): NavigationRail

## Components and Interfaces

### 1. HomeShell (Modified)

**Purpose**: Main application shell that adapts navigation based on screen size.

**Pseudocode**:
```dart
class HomeShell extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        
        if (isDesktop) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: currentIndex,
                onDestinationSelected: onNavigate,
                destinations: navItems.map((item) => 
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    label: Text(item.label),
                  )
                ).toList(),
              ),
              Expanded(child: child),
            ],
          );
        } else {
          return Scaffold(
            body: child,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: onNavigate,
              items: navItems.map((item) => 
                BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                )
              ).toList(),
            ),
          );
        }
      },
    );
  }
}
```

### 2. PlatformService

**Purpose**: Centralized platform detection and configuration.

**Pseudocode**:
```dart
class PlatformService {
  static bool get isDesktop => 
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  
  static bool get isMobile => 
    Platform.isAndroid || Platform.isIOS;
  
  static bool get supportsCameraFeatures => isMobile;
  
  static bool get supportsVoiceRecording => isMobile;
  
  static String get platformName {
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }
}
```

### 3. WindowManager (Desktop Only)

**Purpose**: Manage desktop window properties.

**Pseudocode**:
```dart
class WindowManager {
  static Future<void> initialize() async {
    if (!PlatformService.isDesktop) return;
    
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      title: 'CordysCRM',
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  
  static Future<void> saveWindowState() async {
    if (!PlatformService.isDesktop) return;
    
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    
    // Save to SharedPreferences
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
    await prefs.setDouble('window_x', position.dx);
    await prefs.setDouble('window_y', position.dy);
  }
  
  static Future<void> restoreWindowState() async {
    if (!PlatformService.isDesktop) return;
    
    final width = prefs.getDouble('window_width') ?? 1200;
    final height = prefs.getDouble('window_height') ?? 800;
    final x = prefs.getDouble('window_x');
    final y = prefs.getDouble('window_y');
    
    await windowManager.setSize(Size(width, height));
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
  }
}
```

### 4. AdaptiveFilePicker

**Purpose**: Platform-appropriate file selection.

**Pseudocode**:
```dart
class AdaptiveFilePicker {
  static Future<List<File>> pickImages() async {
    if (PlatformService.isMobile) {
      // Use image_picker for mobile
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      return images.map((xfile) => File(xfile.path)).toList();
    } else {
      // Use file_picker for desktop
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      return result?.files.map((file) => File(file.path!)).toList() ?? [];
    }
  }
  
  static Future<File?> pickFile({List<String>? allowedExtensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions != null ? FileType.custom : FileType.any,
      allowedExtensions: allowedExtensions,
    );
    return result?.files.single.path != null 
      ? File(result!.files.single.path!) 
      : null;
  }
}
```

### 5. AdaptiveWebView

**Purpose**: Platform-appropriate WebView implementation.

**Pseudocode**:
```dart
class AdaptiveWebView extends StatelessWidget {
  final String url;
  final Function(String)? onUrlChanged;
  
  Widget build(BuildContext context) {
    if (PlatformService.isMobile) {
      return InAppWebView(
        initialUrlRequest: URLRequest(url: Uri.parse(url)),
        onLoadStop: (controller, url) {
          onUrlChanged?.call(url.toString());
        },
      );
    } else {
      // Use desktop_webview_window for desktop
      return DesktopWebView(
        url: url,
        onUrlChanged: onUrlChanged,
      );
    }
  }
}
```

## Data Models

No changes to existing data models are required. All entities, DTOs, and database schemas remain the same across platforms.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Layout Consistency
*For any* screen width, the system should display exactly one navigation component (either NavigationRail or BottomNavigationBar), never both or neither.
**Validates: Requirements 2.1, 2.2**

### Property 2: Navigation State Preservation
*For any* navigation action, switching between mobile and desktop layouts should preserve the current navigation index.
**Validates: Requirements 2.5**

### Property 3: Platform Detection Accuracy
*For any* platform, `PlatformService.isDesktop` should return true if and only if the platform is Windows, macOS, or Linux.
**Validates: Requirements 4.4**

### Property 4: Window Size Constraints
*For any* window resize operation on desktop, the window dimensions should never be smaller than the minimum size (800x600).
**Validates: Requirements 5.2**

### Property 5: Feature Availability Consistency
*For any* mobile-only feature (camera, voice recording), the feature should be disabled on desktop platforms and enabled on mobile platforms.
**Validates: Requirements 4.1**

### Property 6: Data Storage Path Correctness
*For any* platform, the database file path should follow platform-specific conventions and be accessible by the application.
**Validates: Requirements 6.2**

### Property 7: Responsive Breakpoint Accuracy
*For any* screen width W, if W >= 600px then NavigationRail is displayed, if W < 600px then BottomNavigationBar is displayed.
**Validates: Requirements 2.1, 2.2**

## Error Handling

### Platform-Specific Errors

1. **Desktop Window Initialization Failure**:
   - Fallback to default window size
   - Log error for debugging
   - Continue app initialization

2. **File Picker Unavailable**:
   - Show error message to user
   - Provide alternative input method (URL input for images)

3. **WebView Initialization Failure**:
   - Show error message
   - Provide option to open in external browser

### Layout Errors

1. **Invalid Screen Dimensions**:
   - Use safe defaults (mobile layout)
   - Log warning

2. **Navigation State Mismatch**:
   - Reset to home page
   - Log error

## Testing Strategy

### Unit Tests

- Test `PlatformService` platform detection logic
- Test responsive layout breakpoint calculations
- Test window size constraint validation
- Test file picker platform selection logic

### Widget Tests

- Test `HomeShell` renders NavigationRail on wide screens
- Test `HomeShell` renders BottomNavigationBar on narrow screens
- Test navigation state preservation across layout changes
- Test adaptive components render correctly on each platform

### Integration Tests

- Test full navigation flow on desktop layout
- Test window resize behavior
- Test file selection on desktop
- Test data persistence across platforms

### Property-Based Tests

Each correctness property should be implemented as a property-based test using the `fast_check` equivalent for Dart (or custom generators):

- **Property 1**: Generate random screen widths, verify only one navigation component is rendered
- **Property 2**: Generate random navigation sequences, verify state preservation
- **Property 3**: Test all platform combinations, verify detection accuracy
- **Property 4**: Generate random window resize operations, verify constraints
- **Property 5**: Test feature availability on all platforms
- **Property 6**: Verify storage paths on all platforms
- **Property 7**: Generate random screen widths, verify correct layout selection

**Test Configuration**:
- Minimum 100 iterations per property test
- Tag format: **Feature: flutter-desktop-adaptation, Property {number}: {property_text}**

