# 企业搜索"查看详情"超时问题修复

## 问题描述

在企业搜索中点击"查看详情"时，会提示"自动获取超时"。从日志中发现两个主要问题：

1. **堆栈溢出错误**：`RangeError: Maximum call stack size exceeded`
2. **超时时间过短**：10秒超时对于复杂页面来说不够

## 根本原因

### 1. 递归调用导致堆栈溢出

在 `qcc_data_source.dart` 的 `findValueByLabel` 函数中：

```dart
// 策略3：如果在限定范围内没找到，扩展到全局搜索
if (root !== document) {
  debug('在限定范围内未找到，扩展到全局搜索');
  return findValueByLabel(labels, null);  // ❌ 可能导致无限递归
}
```

问题：
- 当 `rootSelector` 为 `null` 时，会选择默认的基本信息区域
- 如果在基本信息区域没找到，会递归调用自己进行全局搜索
- 但全局搜索时又可能选择基本信息区域，导致无限递归

### 2. 超时时间不足

```dart
_autoExtractTimeoutTimer = Timer(const Duration(seconds: 10), () {
  // 10秒对于复杂页面和网络较慢的情况不够
});
```

## 修复方案

### 1. 修复递归调用（已完成）

**文件**: `mobile/cordyscrm_flutter/lib/data/datasources/qcc_data_source.dart`

**改进**:
1. 添加 `_isGlobalSearch` 参数标记是否已经是全局搜索
2. 限制最大遍历元素数为 500，避免处理过多元素
3. 确保全局搜索只执行一次，不会再次递归

```javascript
const findValueByLabel = (labels, rootSelector, _isGlobalSearch) => {
  // 确定搜索范围
  let root;
  if (_isGlobalSearch) {
    root = document;  // 全局搜索直接使用 document
  } else if (rootSelector) {
    root = document.querySelector(rootSelector);
    if (!root) root = document;
  } else {
    // 默认先在基本信息区域搜索
    root = document.querySelector('.cominfo-normal, .basic-info, .company-info, .ntable') || document;
  }
  
  // ... 查找逻辑 ...
  
  // 限制最大遍历元素数
  const maxElements = 500;
  const elementsToCheck = Array.from(elements).slice(0, maxElements);
  
  // 只在非全局搜索时才递归一次
  if (root !== document && !_isGlobalSearch) {
    debug('在限定范围内未找到，扩展到全局搜索');
    return findValueByLabel(labels, null, true);  // ✅ 标记为全局搜索
  }
  
  return '';
};
```

### 2. 增加超时时间（已完成）

**文件**: `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart`

**改进**:
- 超时时间从 10秒 增加到 20秒
- 优化错误提示文案，更友好

```dart
// 设置超时定时器（20秒后如果还没提取成功，提示用户手动操作）
_autoExtractTimeoutTimer?.cancel();
_autoExtractTimeoutTimer = Timer(const Duration(seconds: 20), () {
  if (_pendingAutoExtract && mounted) {
    debugPrint('[企查查] 自动提取超时');
    setState(() {
      _pendingAutoExtract = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('页面加载较慢，请稍后点击"导入CRM"按钮手动提取'),
        duration: Duration(seconds: 5),
        backgroundColor: Colors.orange,
      ),
    );
  }
});
```

## 测试步骤

### 1. 重新连接设备并安装

```bash
# 检查设备连接
adb devices

# 重新运行应用
cd mobile/cordyscrm_flutter
flutter run -d <device_id>
```

### 2. 测试场景

1. **基本测试**：
   - 搜索企业（如"九鼎"）
   - 点击搜索结果中的"查看详情"
   - 观察是否能成功自动提取数据
   - 检查日志中是否还有堆栈溢出错误

2. **超时测试**：
   - 在网络较慢的情况下测试
   - 观察是否在 20秒后显示友好的提示信息
   - 确认可以手动点击"导入CRM"按钮提取数据

3. **日志检查**：
   ```bash
   flutter logs -d <device_id> | grep -E "QCC-DEBUG|企查查|RangeError"
   ```

## 预期效果

### 修复前
- ❌ 点击"查看详情"后 10秒超时
- ❌ 日志显示 `RangeError: Maximum call stack size exceeded`
- ❌ 无法自动提取企业数据

### 修复后
- ✅ 超时时间延长到 20秒，给页面更多加载时间
- ✅ 修复递归调用，不再出现堆栈溢出
- ✅ 限制遍历元素数，提高性能
- ✅ 友好的错误提示，引导用户手动操作

## 后续优化建议

1. **性能优化**：
   - 考虑使用 Web Worker 进行数据提取，避免阻塞主线程
   - 优化 DOM 查询策略，减少不必要的遍历

2. **用户体验**：
   - 添加加载进度指示器
   - 提供"跳过自动提取"选项
   - 缓存已提取的企业数据

3. **错误处理**：
   - 区分不同类型的错误（网络错误、解析错误、超时）
   - 提供更具体的错误提示和解决方案

4. **监控和日志**：
   - 记录提取成功率
   - 统计平均提取时间
   - 收集失败案例用于优化

## 相关文件

- `mobile/cordyscrm_flutter/lib/data/datasources/qcc_data_source.dart` - 企查查数据源
- `mobile/cordyscrm_flutter/lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart` - 企业搜索页面
- `ANDROID_USB_TEST_STATUS.md` - 测试状态报告

## 提交信息

```bash
git add mobile/cordyscrm_flutter/lib/data/datasources/qcc_data_source.dart
git add mobile/cordyscrm_flutter/lib/presentation/features/enterprise/enterprise_search_with_webview_page.dart
git commit -m "fix(flutter): 修复企业详情自动提取超时和堆栈溢出问题

- 修复 findValueByLabel 递归调用导致的堆栈溢出
- 添加全局搜索标记，确保只递归一次
- 限制最大遍历元素数为 500，提高性能
- 超时时间从 10秒 增加到 20秒
- 优化超时提示文案，更友好

Fixes: 企业搜索查看详情时提示自动获取超时"
```
