# Implementation Plan: Flutter Dependency Fix

## Overview

本实现计划将 Flutter 依赖升级任务分解为可执行的步骤。采用保守策略，优先修复 `file_picker` 问题，然后验证构建和功能。

## Tasks

- [ ] 1. 备份当前依赖配置
  - 创建 `pubspec.yaml.backup` 和 `pubspec.lock.backup`
  - 记录当前 Flutter 版本和 Dart 版本
  - _Requirements: N/A (安全措施)_

- [ ] 2. 清理构建缓存
  - 运行 `flutter clean` 清理所有构建产物
  - 删除 `.dart_tool` 目录（如果存在）
  - _Requirements: 2.1_

- [ ] 3. 升级 Flutter 依赖
  - 运行 `flutter pub upgrade` 升级所有依赖
  - 检查升级日志，确认 `file_picker` 升级到 10.x 或更高版本
  - 检查是否有依赖冲突警告
  - _Requirements: 1.1, 1.2_

- [ ] 4. 重新获取依赖
  - 运行 `flutter pub get` 确保所有依赖正确下载
  - 验证 `pubspec.lock` 已更新
  - _Requirements: 2.2_

- [ ] 5. 运行静态分析
  - 运行 `flutter analyze` 检查代码问题
  - 记录所有错误和警告
  - 如果有错误，标记需要修复的文件
  - _Requirements: 1.3, 3.2_

- [ ] 6. 检查 adaptive_file_picker.dart 兼容性
  - 打开 `lib/core/utils/adaptive_file_picker.dart`
  - 检查 `FilePicker.platform.pickFiles()` 调用是否需要更新
  - 检查 `FilePickerResult` 类型使用是否正确
  - 如有 API 变更，更新代码
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 7. 检查其他受影响的代码
  - 搜索项目中所有使用 `file_picker` 的地方
  - 检查是否有编译错误或警告
  - 更新受影响的代码（如有）
  - _Requirements: 3.2, 3.3_

- [ ] 8. 尝试构建 Android APK
  - 运行 `flutter build apk --debug`
  - 如果失败，记录错误信息
  - 如果成功，继续下一步
  - _Requirements: 2.3, 2.4_

- [ ] 9. Checkpoint - 构建验证
  - 确认 Android 构建成功
  - 确认没有 "cannot find symbol: class Registrar" 错误
  - 如有问题，回滚并尝试 Fallback Strategy
  - _Requirements: 2.3, 2.4_

- [ ] 10. 在真机上运行应用
  - 运行 `flutter run -d <device_id>`
  - 确认应用成功启动
  - 确认没有运行时错误
  - _Requirements: 4.1_

- [ ] 11. 测试文件选择功能
  - 在应用中触发文件选择（如编辑客户页面的图片上传）
  - 确认文件选择器正常打开
  - 确认文件选择后正常返回
  - _Requirements: 3.1_

- [ ] 12. 测试后端集成
  - 测试登录功能
  - 测试数据同步功能
  - 测试企业搜索功能
  - 确认所有后端交互正常
  - _Requirements: 4.2, 4.3_

- [ ] 13. Final Checkpoint - 代码审核和提交
  - 使用 Codex MCP 审核代码改动
  - 运行 `flutter analyze` 确保无警告
  - 删除备份文件（如果一切正常）
  - 提交代码：`git commit -m "fix(flutter): 升级 file_picker 修复 Android 构建问题"`
  - _Requirements: All_

## Rollback Plan

如果任务 8 或 9 失败：

1. 恢复备份：
   ```bash
   cp pubspec.yaml.backup pubspec.yaml
   cp pubspec.lock.backup pubspec.lock
   flutter pub get
   ```

2. 尝试 Fallback Strategy（选择性升级或使用兼容版本）

3. 如果仍然失败，咨询用户是否考虑降级 Flutter SDK

## Notes

- 任务 1-4 是准备和升级阶段，风险较低
- 任务 5-7 是兼容性检查，可能需要代码修改
- 任务 8-9 是关键验证点，决定是否继续或回滚
- 任务 10-12 是功能验证，确保升级没有破坏现有功能
- 每个 Checkpoint 都需要用户确认才能继续
