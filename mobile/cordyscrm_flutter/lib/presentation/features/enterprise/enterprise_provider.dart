import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/enterprise_repository_impl.dart';
import '../../../domain/entities/enterprise.dart';
import '../../../domain/repositories/enterprise_repository.dart';

// ==================== Repository Provider ====================

/// 企业仓库 Provider
///
/// 默认使用 Mock 实现，生产环境需要替换为真实实现
final enterpriseRepositoryProvider = Provider<EnterpriseRepository>((ref) {
  // TODO: 生产环境替换为 EnterpriseRepositoryImpl
  return MockEnterpriseRepository();
});

// ==================== WebView State ====================

/// WebView 状态
class EnterpriseWebState {
  const EnterpriseWebState({
    this.progress = 0,
    this.isLoading = false,
    this.sessionExpired = false,
    this.pendingEnterprise,
    this.isImporting = false,
    this.importResult,
    this.error,
  });

  /// 加载进度 (0-100)
  final int progress;

  /// 是否正在加载
  final bool isLoading;

  /// 会话是否过期
  final bool sessionExpired;

  /// 待导入的企业信息
  final Enterprise? pendingEnterprise;

  /// 是否正在导入
  final bool isImporting;

  /// 导入结果
  final EnterpriseImportResult? importResult;

  /// 错误信息
  final String? error;

  bool get hasError => error != null;
  bool get hasPending => pendingEnterprise != null;

  EnterpriseWebState copyWith({
    int? progress,
    bool? isLoading,
    bool? sessionExpired,
    Enterprise? pendingEnterprise,
    bool? isImporting,
    EnterpriseImportResult? importResult,
    String? error,
    bool clearPending = false,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return EnterpriseWebState(
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      pendingEnterprise:
          clearPending ? null : (pendingEnterprise ?? this.pendingEnterprise),
      isImporting: isImporting ?? this.isImporting,
      importResult: clearResult ? null : (importResult ?? this.importResult),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ==================== WebView Provider ====================

/// WebView 状态 Provider
final enterpriseWebProvider =
    StateNotifierProvider<EnterpriseWebNotifier, EnterpriseWebState>((ref) {
  return EnterpriseWebNotifier(ref.read(enterpriseRepositoryProvider));
});

/// WebView 状态 Notifier
class EnterpriseWebNotifier extends StateNotifier<EnterpriseWebState> {
  EnterpriseWebNotifier(this._repository) : super(const EnterpriseWebState());

  final EnterpriseRepository _repository;

  /// 更新加载进度
  void setProgress(int progress) {
    state = state.copyWith(
      progress: progress,
      isLoading: progress < 100,
    );
  }

  /// 标记会话过期
  void markSessionExpired() {
    state = state.copyWith(sessionExpired: true);
  }

  /// 清除会话过期标记
  void clearSessionExpired() {
    state = state.copyWith(sessionExpired: false);
  }

  /// 设置待导入的企业信息
  void setPendingEnterprise(Enterprise? enterprise) {
    state = state.copyWith(
      pendingEnterprise: enterprise,
      clearPending: enterprise == null,
      clearResult: true,
    );
  }

  /// 从 JavaScript 回调解析企业信息
  void onEnterpriseCaptured(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final enterprise = Enterprise.fromJson(map);
      setPendingEnterprise(enterprise);
    } catch (e) {
      state = state.copyWith(error: '解析企业信息失败: $e');
    }
  }

  /// 更新待导入的企业信息
  void updatePendingEnterprise(Enterprise enterprise) {
    state = state.copyWith(pendingEnterprise: enterprise);
  }

  /// 导入待处理的企业
  Future<bool> importPending({bool forceOverwrite = false}) async {
    final enterprise = state.pendingEnterprise;
    if (enterprise == null) return false;

    state = state.copyWith(isImporting: true, clearError: true);

    try {
      final result = await _repository.importEnterprise(
        enterprise: enterprise,
        forceOverwrite: forceOverwrite,
      );

      state = state.copyWith(
        isImporting: false,
        importResult: result,
        clearPending: result.isSuccess,
      );

      return result.isSuccess;
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        error: '导入失败: $e',
      );
      return false;
    }
  }

  /// 清除导入结果
  void clearImportResult() {
    state = state.copyWith(clearResult: true);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 取消导入
  void cancelImport() {
    state = state.copyWith(clearPending: true, clearResult: true);
  }

  /// 加载 Cookie
  Future<void> loadCookies() async {
    await _repository.loadCookies();
  }

  /// 保存 Cookie
  Future<void> saveCookies(Map<String, String> cookies) async {
    await _repository.saveCookies(cookies);
  }
}
