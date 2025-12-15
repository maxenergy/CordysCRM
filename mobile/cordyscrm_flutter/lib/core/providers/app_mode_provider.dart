import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 应用模式 Provider
/// 
/// 控制应用是否使用模拟数据模式
/// - true: 模拟模式，使用本地假数据
/// - false: 在线模式，连接真实后端
final isMockModeProvider = StateProvider<bool>((ref) => true);
