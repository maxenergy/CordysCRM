# CordysCRM Flutter 企查查测试指南

## 测试环境

- 后端 IP: 192.168.31.22:8081
- 测试手机号: 13902213704
- 设备: 通过 USB ADB 连接的 Android 手机

## 快速测试步骤

### 1. 启动应用

```bash
# 强制停止并重新启动应用
adb shell am force-stop cn.cordys.cordyscrm_flutter
adb shell am start -n "cn.cordys.cordyscrm_flutter/cn.cordys.cordyscrm_flutter.MainActivity"
```

### 2. 打开企查查 WebView

在应用首页，点击右上角的 "打开企查查" 按钮，或使用 ADB 命令：

```bash
# 点击 "打开企查查" 按钮 (坐标基于 1080x2400 分辨率)
adb shell input tap 1008 191
```

### 3. 手动登录企查查

在企查查 WebView 中：
1. 点击页面右上角的 "登录" 按钮
2. 选择 "手机号登录"
3. 输入手机号: `13902213704`
4. 获取并输入短信验证码
5. 完成登录

### 4. 测试企业搜索

登录成功后，在企查查搜索框中搜索企业：

```bash
# 点击搜索框 (WebView 内部，坐标需要根据实际页面调整)
adb shell input tap 540 400

# 输入搜索关键词 (注意: adb input text 不支持中文)
adb shell input text "alibaba"

# 按回车搜索
adb shell input keyevent KEYCODE_ENTER
```

### 5. 测试数据提取

1. 点击搜索结果中的企业
2. 等待企业详情页加载
3. 点击右下角的 "导入CRM" 浮动按钮
4. 验证数据是否正确提取

### 6. 截图命令

```bash
# 截取当前屏幕
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png ./screenshot.png

# 获取 UI 层级 (仅限原生 UI，WebView 内部无法获取)
adb shell uiautomator dump /sdcard/ui.xml
adb pull /sdcard/ui.xml ./ui.xml
```

## 自动化测试脚本

运行完整的半自动化测试：

```bash
./scripts/test_qichacha_login.sh
```

## 测试截图

测试过程中的截图保存在 `scripts/screenshots/` 目录。

## 已知限制

1. **WebView 内部元素无法通过 uiautomator 获取** - 只能通过坐标点击
2. **验证码需要手动输入** - 无法自动化
3. **中文输入** - `adb shell input text` 不支持中文，需要使用剪贴板方式

## 中文输入方法

```bash
# 方法1: 使用 ADB 广播发送中文
adb shell am broadcast -a ADB_INPUT_TEXT --es msg "阿里巴巴"

# 方法2: 使用剪贴板 (需要应用支持)
# 先复制文本到剪贴板，然后粘贴
```

## 故障排除

### 应用无法启动
```bash
# 检查应用是否安装
adb shell pm list packages | grep cordys

# 查看应用日志
adb logcat -s flutter
```

### WebView 加载失败
```bash
# 检查网络连接
adb shell ping -c 3 www.qcc.com
```

### 坐标不准确
```bash
# 开启开发者选项中的 "指针位置" 来获取准确坐标
# 或使用 uiautomator dump 获取元素边界
```
