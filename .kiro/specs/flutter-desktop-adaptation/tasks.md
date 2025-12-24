# Implementation Plan: Flutter Desktop Adaptation

## Overview

将 Flutter 移动端 CRM 应用适配到桌面平台，实现响应式布局和平台特定功能。

## Tasks

- [x] 1. 启用桌面平台支持
  - 在 `mobile/cordyscrm_flutter` 目录执行 `flutter create --platforms=windows,macos,linux .`
  - 验证生成的 `windows/`, `macos/`, `linux/` 目录
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. 移除移动端限制
  - [x] 2.1 修改 `lib/main.dart` 移除屏幕方向锁定
    - 注释或删除 `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`
    - _Requirements: 1.4_
  - [x] 2.2 更新 `pubspec.yaml` 添加桌面依赖
    - 添加 `window_manager: ^0.3.7` (窗口管理)
    - 添加 `desktop_webview_window: ^0.2.3` (桌面 WebView)
    - 添加 `file_picker: ^6.1.1` (已有，确认版本)
    - _Requirements: 1.5, 4.3_

- [x] 3. 创建平台检测服务
  - [x] 3.1 创建 `lib/core/services/platform_service.dart`
    - 实现 `isDesktop`, `isMobile`, `supportsCameraFeatures`, `supportsVoiceRecording` getters
    - 实现 `platformName` getter
    - _Requirements: 4.4_
  - [ ]* 3.2 编写平台检测的属性测试
    - **Property 3: Platform Detection Accuracy**
    - **Validates: Requirements 4.4**

- [x] 4. 实现响应式 HomeShell
  - [x] 4.1 修改 `lib/presentation/features/home/home_shell.dart`
    - 使用 `LayoutBuilder` 检测屏幕宽度
    - 宽度 >= 600px 时显示 `NavigationRail`
    - 宽度 < 600px 时显示 `BottomNavigationBar`
    - 保持导航状态一致
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_
  - [ ]* 4.2 编写响应式布局的属性测试
    - **Property 1: Layout Consistency**
    - **Property 7: Responsive Breakpoint Accuracy**
    - **Validates: Requirements 2.1, 2.2**
  - [ ]* 4.3 编写导航状态的属性测试
    - **Property 2: Navigation State Preservation**
    - **Validates: Requirements 2.5**

- [x] 5. 实现窗口管理
  - [x] 5.1 创建 `lib/core/services/window_manager_service.dart`
    - 实现 `initialize()` 设置默认窗口大小和最小尺寸
    - 实现 `saveWindowState()` 保存窗口状态
    - 实现 `restoreWindowState()` 恢复窗口状态
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  - [x] 5.2 在 `lib/main.dart` 中初始化窗口管理
    - 在 `main()` 函数中调用 `WindowManagerService.initialize()`
    - 仅在桌面平台执行
    - _Requirements: 5.1, 5.2_
  - [ ]* 5.3 编写窗口尺寸约束的属性测试
    - **Property 4: Window Size Constraints**
    - **Validates: Requirements 5.2**

- [x] 6. Checkpoint - 基础适配验证
  - 在桌面平台运行应用: `flutter run -d windows` (或 macos/linux)
  - 验证响应式布局切换正常
  - 验证窗口可以调整大小
  - 验证导航功能正常
  - 如有问题，请告知用户

- [x] 7. 创建自适应文件选择器
  - [x] 7.1 创建 `lib/core/utils/adaptive_file_picker.dart`
    - 实现 `pickImages()` 方法（移动端用 image_picker，桌面端用 file_picker）
    - 实现 `pickFile()` 方法
    - _Requirements: 4.2_
  - [x] 7.2 更新使用文件选择的组件
    - 修改 `lib/presentation/widgets/image_picker_grid.dart` 使用 `AdaptiveFilePicker`
    - 修改跟进记录表单使用自适应文件选择
    - _Requirements: 4.2_

- [x] 8. 处理移动端特有功能
  - [x] 8.1 修改语音录制组件
    - 在 `lib/presentation/widgets/audio_recorder_widget.dart` 中添加平台检测
    - 桌面端显示"此功能仅在移动端可用"提示
    - _Requirements: 4.1_
  - [x] 8.2 修改相机功能
    - 在图片选择器中禁用桌面端的相机选项
    - 仅保留"从文件选择"选项
    - _Requirements: 4.1_
  - [ ]* 8.3 编写功能可用性的属性测试
    - **Property 5: Feature Availability Consistency**
    - **Validates: Requirements 4.1**

- [-] 9. 适配 WebView 功能
  - [ ] 9.1 创建 `lib/presentation/widgets/adaptive_webview.dart`
    - 移动端使用 `flutter_inappwebview`
    - 桌面端使用 `desktop_webview_window`
    - 统一接口和回调
    - _Requirements: 4.3_
  - [ ] 9.2 更新企业搜索 WebView 页面
    - 修改 `lib/presentation/features/enterprise/enterprise_webview_page.dart`
    - 使用 `AdaptiveWebView` 组件
    - _Requirements: 4.3_

- [ ] 10. 桌面端 UI 优化
  - [x] 10.1 更新主题配置
    - 在 `lib/presentation/theme/app_theme.dart` 中添加桌面端特定样式
    - 增加桌面端的 padding 和 spacing
    - 添加 hover 效果样式
    - _Requirements: 3.1, 3.3_
  - [x] 10.2 添加键盘快捷键支持
    - 创建 `lib/core/utils/keyboard_shortcuts.dart`
    - 实现常用快捷键（Ctrl+N 新建、Ctrl+S 保存、Ctrl+F 搜索等）
    - _Requirements: 3.2_
  - [x] 10.3 设置最小窗口尺寸
    - 在窗口管理服务中设置 minimumSize 为 800x600
    - _Requirements: 3.5_

- [ ] 11. 数据存储路径适配
  - [ ] 11.1 验证 Drift 数据库路径
    - 确认 `lib/data/sources/local/app_database.dart` 使用平台适当路径
    - 桌面端使用 `path_provider` 的 `getApplicationDocumentsDirectory()`
    - _Requirements: 6.2_
  - [ ]* 11.2 编写存储路径的属性测试
    - **Property 6: Data Storage Path Correctness**
    - **Validates: Requirements 6.2**

- [ ] 12. 性能优化
  - [ ] 12.1 优化列表渲染
    - 在客户、线索、商机列表中增加桌面端的每页数量（50 条）
    - 移动端保持 20 条
    - _Requirements: 7.2_
  - [ ] 12.2 优化图片加载
    - 桌面端使用更高分辨率的图片缓存
    - 调整缓存策略
    - _Requirements: 7.1_

- [ ] 13. Checkpoint - 功能完整性验证
  - 测试所有核心功能在桌面端正常工作
  - 测试文件选择功能
  - 测试 WebView 功能
  - 测试数据同步
  - 测试窗口管理
  - 如有问题，请告知用户

- [ ] 14. 编写测试
  - [ ]* 14.1 编写单元测试
    - 测试 `PlatformService` 的所有方法
    - 测试 `WindowManagerService` 的窗口状态管理
    - 测试 `AdaptiveFilePicker` 的平台选择逻辑
    - _Requirements: 8.1, 8.4_
  - [ ]* 14.2 编写 Widget 测试
    - 测试 `HomeShell` 在不同屏幕宽度下的渲染
    - 测试 `AdaptiveWebView` 的平台适配
    - 测试导航状态保持
    - _Requirements: 8.2_
  - [ ]* 14.3 编写集成测试
    - 测试完整的桌面端导航流程
    - 测试窗口调整大小行为
    - 测试文件选择流程
    - _Requirements: 8.3_

- [ ] 15. 文档更新
  - [ ] 15.1 更新 README.md
    - 添加桌面端运行说明
    - 添加桌面端构建说明
    - 添加平台特定注意事项
  - [ ] 15.2 更新开发状态文档
    - 在 `memory-bank/development-status.md` 中添加桌面端适配完成状态

- [ ] 16. Final Checkpoint - 全平台验证
  - 在 Windows 上运行并测试: `flutter run -d windows`
  - 在 macOS 上运行并测试: `flutter run -d macos`
  - 在 Linux 上运行并测试: `flutter run -d linux`
  - 运行所有测试: `flutter test`
  - 运行代码分析: `flutter analyze`
  - 确保所有平台功能正常，如有问题请告知用户

## Notes

- 任务标记 `*` 的为可选任务（测试相关），可以跳过以加快 MVP 开发
- 每个任务引用了具体的需求条款以便追溯
- Checkpoint 任务用于验证阶段性成果
- 桌面端开发建议优先在一个平台（如 Windows 或 macOS）上完成，然后再测试其他平台

