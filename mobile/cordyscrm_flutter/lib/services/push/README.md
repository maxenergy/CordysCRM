# 推送通知服务配置指南

## 概述

本服务使用 Firebase Cloud Messaging (FCM) 实现推送通知功能。在使用前，需要完成以下配置步骤。

## 配置步骤

### 1. 创建 Firebase 项目

1. 访问 [Firebase Console](https://console.firebase.google.com/)
2. 点击"添加项目"创建新项目
3. 按照向导完成项目创建

### 2. 添加 Android 应用

1. 在 Firebase Console 中，点击"添加应用" > "Android"
2. 输入 Android 包名：`com.cordys.crm.flutter`（或您的实际包名）
3. 下载 `google-services.json` 文件
4. 将文件放置到 `android/app/google-services.json`

### 3. 添加 iOS 应用

1. 在 Firebase Console 中，点击"添加应用" > "iOS"
2. 输入 iOS Bundle ID：`com.cordys.crm.flutter`（或您的实际 Bundle ID）
3. 下载 `GoogleService-Info.plist` 文件
4. 将文件放置到 `ios/Runner/GoogleService-Info.plist`

### 4. 配置 Android

在 `android/build.gradle` 中添加：

```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

在 `android/app/build.gradle` 末尾添加：

```gradle
apply plugin: 'com.google.gms.google-services'
```

### 5. 配置 iOS

在 Xcode 中：

1. 打开 `ios/Runner.xcworkspace`
2. 选择 Runner 项目
3. 在 "Signing & Capabilities" 中添加 "Push Notifications" 能力
4. 添加 "Background Modes" 能力，勾选 "Remote notifications"

### 6. 初始化服务

在 `main.dart` 中初始化：

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Firebase
  await Firebase.initializeApp();
  
  // ... 其他初始化代码
  
  runApp(MyApp());
}
```

在应用启动后初始化推送服务：

```dart
final pushNotifier = ref.read(pushNotificationProvider.notifier);
await pushNotifier.initialize();
```

## 通知数据格式

推送通知的 `data` 字段应包含以下内容：

```json
{
  "type": "customer|clue|opportunity|task",
  "id": "12345"
}
```

## 测试推送

可以使用 Firebase Console 的 Cloud Messaging 功能发送测试通知：

1. 进入 Firebase Console > Cloud Messaging
2. 点击"发送第一条消息"
3. 填写通知标题和内容
4. 选择目标设备或主题
5. 在"其他选项"中添加自定义数据

## 注意事项

- iOS 模拟器不支持推送通知，请使用真机测试
- 确保设备已连接网络
- 首次运行时会请求通知权限，用户需要允许
