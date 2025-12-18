# 交互式调试规则

## 核心方法：前后端抓取打印 + 用户实时反馈

当调试涉及前后端交互、WebView/JS 注入、网页抓取等复杂场景时，必须采用以下方法：

### 1. 添加详细日志打印

**前端/客户端侧：**
- 在关键数据流节点添加 `debugPrint()` 或 `_logger.d()` 日志
- 打印请求参数、响应数据、中间状态
- 使用结构化格式便于分析：`[模块名] 操作: 数据`

**后端侧：**
- 添加请求/响应日志
- 打印关键业务逻辑的输入输出

**JS 注入脚本：**
- 使用 `console.log()` 打印抓取过程
- 打印 DOM 选择器匹配结果
- 打印提取的原始数据

### 2. 实时联调流程

```
1. 添加日志 → 2. 热重载/重启 → 3. 用户操作 → 4. 查看日志 → 5. 分析问题 → 6. 修复 → 重复
```

### 3. 日志查看命令

**Flutter 日志：**
```bash
flutter logs -d <device_id>
```

**后端日志：**
```bash
tail -f backend/app/logs/app.log
# 或查看控制台输出
```

**WebView JS 日志：**
- 通过 Flutter 的 `onConsoleMessage` 回调捕获
- 或在 JS 中通过 `flutter_inappwebview.callHandler` 传回

### 4. 调试检查清单

- [ ] 数据是否正确发送？（打印请求参数）
- [ ] 数据是否正确接收？（打印响应数据）
- [ ] 数据格式是否正确？（打印类型和结构）
- [ ] DOM 选择器是否匹配？（打印匹配元素数量）
- [ ] 数据转换是否正确？（打印转换前后对比）

### 5. 网页抓取特殊注意

- 网站 DOM 结构可能随时变化，选择器需要多策略兜底
- 打印实际抓取到的 HTML 片段帮助分析
- 区分"搜索结果列表页"和"详情页"的不同抓取逻辑
- 注意反爬虫机制可能导致的页面结构变化

### 6. 经验记录

调试完成后，必须：
1. 将问题和解决方案记录到 memorymcp
2. 更新相关文档说明已知的坑点
3. 考虑添加自动化测试防止回归

## 示例：WebView JS 抓取调试

```javascript
// 添加调试日志
const scrapeResults = () => {
  console.log('[DEBUG] 开始抓取结果');
  
  const items = document.querySelectorAll('.result-item');
  console.log('[DEBUG] 找到元素数量:', items.length);
  
  items.forEach((item, i) => {
    console.log(`[DEBUG] 元素 ${i}:`, item.outerHTML.substring(0, 200));
  });
  
  // ... 抓取逻辑
};
```

```dart
// Flutter 侧捕获 JS 日志
onConsoleMessage: (controller, consoleMessage) {
  debugPrint('[WebView Console] ${consoleMessage.message}');
},
```
