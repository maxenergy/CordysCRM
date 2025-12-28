# Flutter Android 应用安装和测试指南

## 快速安装

### 1. 检查设备连接
```bash
adb devices
```

应该看到类似输出：
```
List of devices attached
d91a2f3    device
```

### 2. 编译 APK
```bash
cd mobile/cordyscrm_flutter
flutter build apk --release
```

编译成功后会生成：
- 文件位置：`build/app/outputs/flutter-apk/app-release.apk`
- 文件大小：约 66.6MB

### 3. 安装到设备
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`-r` 参数表示替换已安装的应用（如果存在）。

### 4. 启动应用
```bash
adb shell monkey -p cn.cordys.cordyscrm_flutter -c android.intent.category.LAUNCHER 1
```

## 测试 SelectionBar 修复

### 测试步骤

1. **打开企业搜索页面**
   - 从主页导航到企业搜索功能

2. **执行搜索**
   - 输入企业名称（至少 2 个字符）
   - 等待搜索结果显示

3. **验证"选择"按钮**
   - ✅ 当有远程企业结果时，AppBar 右侧应显示"选择"按钮
   - ✅ 当所有结果都是本地企业时，不显示"选择"按钮

4. **进入选择模式**
   - 点击"选择"按钮
   - ✅ AppBar 标题变为"选择企业"
   - ✅ 每个列表项显示 Checkbox
   - ✅ **底部显示 SelectionBar**（本次修复的重点）

5. **验证 SelectionBar 功能**
   - ✅ 左侧显示"取消"按钮
   - ✅ 左侧显示"全选" Checkbox
   - ✅ 右侧显示"批量导入 (N)" 按钮
   - ✅ SelectionBar 完全可见，不被遮挡

6. **测试选择功能**
   - 点击列表项的 Checkbox 选择企业
   - ✅ 选中数量实时更新
   - ✅ 全选 Checkbox 状态正确（未选/部分选/全选）

7. **测试全选功能**
   - 点击"全选" Checkbox
   - ✅ 所有可选企业被选中（最多 50 个）
   - ✅ 再次点击取消全选

8. **测试批量导入**
   - 选择至少 1 个企业
   - 点击"批量导入"按钮
   - ✅ 显示确认对话框
   - ✅ 确认后显示进度对话框
   - ✅ 完成后显示结果摘要

9. **测试取消功能**
   - 点击"取消"按钮
   - ✅ 退出选择模式
   - ✅ SelectionBar 消失
   - ✅ Checkbox 消失

10. **测试返回键**
    - 在选择模式下按返回键
    - ✅ 退出选择模式（不退出页面）

## 修复验证要点

### 本次修复的核心问题
**问题：** SelectionBar 在选择模式下不显示

**修复内容：**
1. `bottomNavigationBar` 使用 `null` 替代 `SizedBox.shrink()`
2. `SelectionBar` 的 `SafeArea` 设置 `top: false`

### 验证重点
- ✅ SelectionBar 完全可见
- ✅ SelectionBar 不被键盘遮挡
- ✅ SelectionBar 在全面屏设备上正确显示
- ✅ SelectionBar 的按钮都可以正常点击

## 常见问题

### Q: 应用安装失败
**A:** 尝试先卸载旧版本：
```bash
adb uninstall cn.cordys.cordyscrm_flutter
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Q: 应用启动失败
**A:** 检查日志：
```bash
adb logcat | grep -i flutter
```

### Q: SelectionBar 仍然不显示
**A:** 
1. 确认已安装最新版本（commit f561e7334）
2. 检查是否有远程企业结果（本地企业不显示"选择"按钮）
3. 查看日志确认 `isSelectionMode` 状态

### Q: 如何查看应用日志
**A:**
```bash
# 实时查看日志
adb logcat | grep -E "(flutter|cordys)"

# 查看企业搜索相关日志
adb logcat | grep "企业搜索"

# 查看 SelectionBar 相关日志
adb logcat | grep "SelectionBar"
```

## 开发调试

### 热重载（开发模式）
```bash
cd mobile/cordyscrm_flutter
flutter run
```

然后在代码修改后按 `r` 进行热重载。

### 查看设备信息
```bash
adb shell getprop ro.build.version.release  # Android 版本
adb shell wm size                            # 屏幕分辨率
adb shell wm density                         # 屏幕密度
```

### 截图
```bash
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png
```

### 录屏
```bash
adb shell screenrecord /sdcard/demo.mp4
# 按 Ctrl+C 停止录制
adb pull /sdcard/demo.mp4
```

## 相关文档

- [SELECTION_BAR_FIX.md](./SELECTION_BAR_FIX.md) - 修复详情
- [BATCH_IMPORT_TEST_GUIDE.md](./BATCH_IMPORT_TEST_GUIDE.md) - 批量导入测试指南
- [SELECTION_MODE_DEBUG_GUIDE.md](./SELECTION_MODE_DEBUG_GUIDE.md) - 选择模式调试指南

## 版本信息

- **修复版本：** commit f561e7334
- **APK 大小：** 66.6MB
- **包名：** cn.cordys.cordyscrm_flutter
- **最低 Android 版本：** 根据 pubspec.yaml 配置
