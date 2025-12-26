# Requirements Document: Flutter Dependency Fix for Integration Testing

## Introduction

本规范文档定义了修复 Flutter Android 构建失败问题的需求。当前问题是 `file_picker` 插件版本 6.2.1 与 Flutter 版本不兼容，导致编译错误："cannot find symbol: class Registrar"。这是因为 Flutter 移除了 v1 embedding API，而旧版本的 `file_picker` 仍在使用它。

修复此问题后，我们将能够成功启动 Flutter Android 应用进行后端集成测试。

## Glossary

- **file_picker**: Flutter 插件，用于文件选择功能
- **v1 embedding**: Flutter 旧版插件 API（已废弃）
- **v2 embedding**: Flutter 新版插件 API（当前标准）
- **Integration Testing**: 集成测试，验证 Flutter 应用与后端服务的交互
- **Dependency Upgrade**: 依赖升级，更新项目依赖到兼容版本

## Requirements

### Requirement 1: Upgrade file_picker Plugin

**User Story:** As a developer, I want to upgrade the file_picker plugin to a compatible version, so that the Android build succeeds.

#### Acceptance Criteria

1. WHEN running `flutter pub upgrade` THEN the system SHALL upgrade `file_picker` from 6.2.1 to 10.3.8 or later
2. WHEN the upgrade completes THEN the system SHALL update `pubspec.lock` with the new version
3. WHEN the upgrade completes THEN the system SHALL NOT introduce breaking changes to existing code

### Requirement 2: Verify Build Success

**User Story:** As a developer, I want to verify that the Android build succeeds after the upgrade, so that I can proceed with integration testing.

#### Acceptance Criteria

1. WHEN running `flutter clean` THEN the system SHALL remove all build artifacts
2. WHEN running `flutter pub get` THEN the system SHALL fetch all dependencies successfully
3. WHEN running `flutter build apk --debug` or `flutter run` THEN the system SHALL compile without errors
4. WHEN the build completes THEN the system SHALL NOT show "cannot find symbol: class Registrar" error

### Requirement 3: Maintain Existing Functionality

**User Story:** As a developer, I want to ensure that existing file picker functionality still works after the upgrade, so that no features are broken.

#### Acceptance Criteria

1. WHEN the app uses `adaptive_file_picker.dart` THEN the file picker SHALL work on all platforms (Android, iOS, Desktop)
2. WHEN the app calls file picker methods THEN the API SHALL remain compatible with existing code
3. IF breaking changes exist THEN the system SHALL update affected code to use the new API

### Requirement 4: Enable Integration Testing

**User Story:** As a developer, I want to successfully launch the Flutter Android app, so that I can test backend integration.

#### Acceptance Criteria

1. WHEN running `flutter run -d <device_id>` THEN the app SHALL launch successfully on the connected Android device
2. WHEN the app launches THEN it SHALL connect to the backend at http://localhost:8081 or the configured IP
3. WHEN the app is running THEN developers SHALL be able to test login, data sync, and other backend features
