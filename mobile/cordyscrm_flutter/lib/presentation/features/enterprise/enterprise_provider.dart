import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/app_mode_provider.dart';
import '../../../core/utils/enterprise_url_utils.dart';
import '../../../data/datasources/aiqicha_data_source.dart';
import '../../../data/datasources/qcc_data_source.dart';
import '../../../data/repositories/enterprise_repository_impl.dart';
import '../../../domain/datasources/enterprise_data_source.dart';
import '../../../domain/entities/enterprise.dart';
import '../../../domain/repositories/enterprise_repository.dart';

// ==================== Data Source Providers ====================

/// 当前企业信息查询数据源类型
///
/// 默认值为 `qcc`（企查查），用户可切换到 `iqicha`（爱企查）。
/// 使用 [EnterpriseDataSourceType] 枚举，复用 URL 工具中的定义。
final enterpriseDataSourceTypeProvider =
    StateProvider<EnterpriseDataSourceType>(
      (ref) => EnterpriseDataSourceType.qcc,
    );

/// 企查查数据源实例
///
/// 缓存于 Provider 生命周期内，避免重复创建。
final qccDataSourceProvider = Provider<EnterpriseDataSourceInterface>(
  (ref) => const QccDataSource(),
);

/// 爱企查数据源实例
///
/// 缓存于 Provider 生命周期内，避免重复创建。
/// 注意：枚举值为 `iqicha`，与类名 `AiqichaDataSource` 对应。
final aiqichaDataSourceProvider = Provider<EnterpriseDataSourceInterface>(
  (ref) => const AiqichaDataSource(),
);

/// 当前数据源实例
///
/// 根据 [enterpriseDataSourceTypeProvider] 返回对应的数据源实例。
/// 当类型为 `unknown` 时，回退到默认的企查查数据源。
final enterpriseDataSourceProvider = Provider<EnterpriseDataSourceInterface>((
  ref,
) {
  final type = ref.watch(enterpriseDataSourceTypeProvider);
  return switch (type) {
    EnterpriseDataSourceType.qcc => ref.watch(qccDataSourceProvider),
    EnterpriseDataSourceType.iqicha => ref.watch(aiqichaDataSourceProvider),
    EnterpriseDataSourceType.unknown => ref.watch(qccDataSourceProvider),
  };
});

// ==================== Repository Provider ====================

/// 企业仓库 Provider
///
/// 使用真实实现调用后端 API
final enterpriseRepositoryProvider = Provider<EnterpriseRepository>((ref) {
  return EnterpriseRepositoryImpl(dio: DioClient.instance.dio, ref: ref);
});

// ==================== WebView Search Communication ====================

/// WebView 控制器 Provider
///
/// 由 EnterpriseWebViewPage 设置，供 Repository 使用执行 JS 搜索
final webViewControllerProvider = StateProvider<InAppWebViewController?>(
  (ref) => null,
);

/// 爱企查搜索结果 Completer Provider
///
/// 用于 WebView JS 回调和 Repository 之间的异步通信
final aiqichaSearchCompleterProvider =
    StateProvider<Completer<List<Map<String, String>>>?>((ref) => null);

/// 企查查搜索结果 Completer Provider
///
/// 使用 `Map<requestId, Completer>` 结构支持并发请求关联，避免竞态条件。
/// 每个搜索请求都有唯一的 requestId，JS 回调时携带 requestId 以匹配对应的 Completer。
/// 允许返回两类 payload：List(搜索结果) 或 Map(needNavigate 状态)。
final qichachaSearchCompleterProvider =
    StateProvider<Map<int, Completer<Object>>>(
      (ref) => <int, Completer<Object>>{},
    );

// ==================== Mock Data (Demo Mode) ====================

/// 演示模式下的模拟企业数据
/// 注意：已清空模拟数据，企业搜索应使用真实的企查查 WebView 搜索
const List<Enterprise> _mockEnterprises = [];

// ==================== Search State ====================

/// 企业搜索数据来源
enum EnterpriseSearchDataSource { local, iqicha, qcc, mixed }

/// 企业搜索状态
class EnterpriseSearchState {
  const EnterpriseSearchState({
    this.isSearching = false,
    this.isReSearching = false,
    this.results = const [],
    this.total = 0,
    this.error,
    this.reSearchError,
    this.keyword = '',
    this.dataSource,
    this.externalDataSourceType,
  });

  final bool isSearching;
  final bool isReSearching;
  final List<Enterprise> results;
  final int total;
  final String? error;
  final String? reSearchError;
  final String keyword;
  final EnterpriseSearchDataSource? dataSource;
  final EnterpriseDataSourceType? externalDataSourceType;

  bool get hasError => error != null;
  bool get hasReSearchError => reSearchError != null;
  bool get hasResults => results.isNotEmpty;

  /// 是否可以执行重新搜索
  ///
  /// 条件：
  /// - 数据来源为本地数据库
  /// - 有搜索结果
  /// - 当前没有正在进行的搜索
  /// - 当前没有正在进行的重新搜索
  bool get canReSearch =>
      dataSource == EnterpriseSearchDataSource.local &&
      results.isNotEmpty &&
      !isSearching &&
      !isReSearching;

  String? get dataSourceLabel {
    return switch (dataSource) {
      EnterpriseSearchDataSource.local => 'CRM 本地库',
      EnterpriseSearchDataSource.iqicha => '爱企查',
      EnterpriseSearchDataSource.qcc => '企查查',
      EnterpriseSearchDataSource.mixed => switch (externalDataSourceType) {
        EnterpriseDataSourceType.iqicha => '本地 + 爱企查',
        EnterpriseDataSourceType.qcc => '本地 + 企查查',
        _ => '本地 + 外部数据源',
      },
      _ => null,
    };
  }

  EnterpriseSearchState copyWith({
    bool? isSearching,
    bool? isReSearching,
    List<Enterprise>? results,
    int? total,
    String? error,
    String? reSearchError,
    String? keyword,
    EnterpriseSearchDataSource? dataSource,
    EnterpriseDataSourceType? externalDataSourceType,
    bool clearError = false,
    bool clearReSearchError = false,
    bool clearDataSource = false,
  }) {
    return EnterpriseSearchState(
      isSearching: isSearching ?? this.isSearching,
      isReSearching: isReSearching ?? this.isReSearching,
      results: results ?? this.results,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
      reSearchError: clearReSearchError
          ? null
          : (reSearchError ?? this.reSearchError),
      keyword: keyword ?? this.keyword,
      dataSource: clearDataSource ? null : (dataSource ?? this.dataSource),
      externalDataSourceType:
          externalDataSourceType ?? this.externalDataSourceType,
    );
  }
}

/// 企业搜索 Provider
final enterpriseSearchProvider =
    StateNotifierProvider<EnterpriseSearchNotifier, EnterpriseSearchState>((
      ref,
    ) {
      return EnterpriseSearchNotifier(
        ref.read(enterpriseRepositoryProvider),
        ref,
      );
    });

/// 企业搜索 Notifier
class EnterpriseSearchNotifier extends StateNotifier<EnterpriseSearchState> {
  EnterpriseSearchNotifier(this._repository, this._ref)
    : super(const EnterpriseSearchState());

  final EnterpriseRepository _repository;
  final Ref _ref;

  /// 当前搜索请求的序号，用于处理竞态条件
  int _searchRequestId = 0;

  /// 搜索企业
  ///
  /// 流程：先查 CRM 本地库，无结果再查爱企查
  /// 在演示模式下返回模拟数据
  Future<void> search(String keyword) async {
    final trimmedKeyword = keyword.trim();

    if (trimmedKeyword.length < 2) {
      // 递增请求序号，使任何进行中的搜索请求失效
      _searchRequestId++;
      state = const EnterpriseSearchState();
      return;
    }

    final isMockMode = _ref.read(isMockModeProvider);

    // 递增请求序号，用于处理竞态条件
    final currentRequestId = ++_searchRequestId;

    state = state.copyWith(
      isSearching: true,
      isReSearching: false, // 清理重新搜索状态
      keyword: trimmedKeyword,
      clearError: true,
      clearReSearchError: true, // 清理重新搜索错误
      clearDataSource: true,
    );

    try {
      // 演示模式：返回模拟数据
      if (isMockMode) {
        await _searchMockData(trimmedKeyword, currentRequestId);
        return;
      }

      // 真实模式：先查 CRM 本地库（后端只查本地数据库，不调用爱企查）
      final localResult = await _repository.searchLocal(
        keyword: trimmedKeyword,
      );

      // 检查是否已被新请求取代或 Provider 已销毁
      if (!mounted || currentRequestId != _searchRequestId) {
        return;
      }

      // 本地有数据：直接展示
      if (localResult.success && localResult.items.isNotEmpty) {
        state = state.copyWith(
          isSearching: false,
          results: localResult.items,
          total: localResult.total,
          dataSource: EnterpriseSearchDataSource.local,
        );
        return;
      }

      // 本地无数据或查询失败：根据当前数据源类型决定使用哪个外部数据源
      // 注意：即使本地查询失败（如 404），也应该尝试外部数据源
      final currentDataSourceType = _ref.read(enterpriseDataSourceTypeProvider);
      final dataSource = _ref.read(enterpriseDataSourceProvider);
      final dataSourceName = dataSource.displayName;

      // 根据数据源类型选择搜索方式
      if (currentDataSourceType == EnterpriseDataSourceType.iqicha) {
        // 爱企查：使用 WebView Cookie 进行 API 搜索
        final iqichaResult = await _repository.searchAiqicha(
          keyword: trimmedKeyword,
        );

        if (!mounted || currentRequestId != _searchRequestId) {
          return;
        }

        if (iqichaResult.success) {
          state = state.copyWith(
            isSearching: false,
            results: iqichaResult.items,
            total: iqichaResult.total,
            dataSource: EnterpriseSearchDataSource.iqicha,
          );
        } else {
          // 爱企查搜索失败（可能是 Cookie 过期或需要验证码）
          state = state.copyWith(
            isSearching: false,
            error: iqichaResult.message ?? '爱企查搜索失败',
            results: [],
            total: 0,
            dataSource: EnterpriseSearchDataSource.iqicha,
          );
        }
      } else {
        // 企查查：通过 WebView 执行 JS 搜索
        final qccResult = await _repository.searchQichacha(
          keyword: trimmedKeyword,
        );

        if (!mounted || currentRequestId != _searchRequestId) {
          return;
        }

        if (qccResult.success) {
          state = state.copyWith(
            isSearching: false,
            results: qccResult.items,
            total: qccResult.total,
            dataSource: EnterpriseSearchDataSource.qcc,
          );
        } else {
          // 企查查搜索失败（可能是 WebView 未打开或需要登录）
          state = state.copyWith(
            isSearching: false,
            error: qccResult.message ?? '请先打开$dataSourceName页面并登录',
            results: [],
            total: 0,
            dataSource: EnterpriseSearchDataSource.qcc,
          );
        }
      }
    } catch (e) {
      // 检查是否已被新请求取代或 Provider 已销毁
      if (!mounted || currentRequestId != _searchRequestId) {
        return;
      }

      state = state.copyWith(
        isSearching: false,
        error: '搜索失败: $e',
        results: [],
        total: 0,
      );
    }
  }

  /// 演示模式下的模拟搜索
  Future<void> _searchMockData(String keyword, int requestId) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));

    // 检查 Provider 是否已销毁或请求已被取代
    if (!mounted || requestId != _searchRequestId) return;

    final kw = keyword.toLowerCase();

    // 在模拟数据中搜索匹配的企业（统一使用小写比对）
    final results = _mockEnterprises.where((enterprise) {
      return enterprise.name.toLowerCase().contains(kw) ||
          enterprise.creditCode.toLowerCase().contains(kw) ||
          enterprise.legalPerson.toLowerCase().contains(kw) ||
          enterprise.address.toLowerCase().contains(kw) ||
          enterprise.industry.toLowerCase().contains(kw);
    }).toList();

    // 再次检查 mounted 状态和请求序号
    if (!mounted || requestId != _searchRequestId) return;

    // 确定数据来源
    final hasLocal = results.any((e) => e.isLocal);
    final hasIqicha = results.any((e) => e.isFromIqicha);
    EnterpriseSearchDataSource? source;
    if (hasLocal && hasIqicha) {
      source = EnterpriseSearchDataSource.mixed;
    } else if (hasLocal) {
      source = EnterpriseSearchDataSource.local;
    } else if (hasIqicha) {
      source = EnterpriseSearchDataSource.iqicha;
    }

    state = state.copyWith(
      isSearching: false,
      results: results,
      total: results.length,
      dataSource: source,
    );
  }

  /// 重新搜索外部数据源
  ///
  /// 仅在当前结果来自本地库时触发外部搜索，并将外部结果追加到本地结果后。
  /// 保留本地结果，成功时更新 dataSource 为 mixed，失败时设置 reSearchError。
  Future<void> reSearchExternal() async {
    if (!state.canReSearch) return;

    final keyword = state.keyword;
    final localResults = state.results;
    final currentRequestId = _searchRequestId;

    state = state.copyWith(isReSearching: true, clearReSearchError: true);

    try {
      final currentDataSourceType = _ref.read(enterpriseDataSourceTypeProvider);

      final externalResult =
          currentDataSourceType == EnterpriseDataSourceType.iqicha
          ? await _repository.searchAiqicha(keyword: keyword)
          : await _repository.searchQichacha(keyword: keyword);

      // 检查是否已被新请求取代或 Provider 已销毁
      if (!mounted || currentRequestId != _searchRequestId) {
        return;
      }

      if (externalResult.success) {
        // 追加外部结果到本地结果之后
        final mergedResults = [...localResults, ...externalResult.items];
        state = state.copyWith(
          isReSearching: false,
          results: mergedResults,
          total: mergedResults.length,
          dataSource: EnterpriseSearchDataSource.mixed,
          externalDataSourceType: currentDataSourceType,
        );
      } else {
        // 失败时保留本地结果，设置错误信息
        state = state.copyWith(
          isReSearching: false,
          reSearchError: externalResult.message ?? '重新搜索失败',
        );
      }
    } catch (e) {
      // 检查是否已被新请求取代或 Provider 已销毁
      if (!mounted || currentRequestId != _searchRequestId) {
        return;
      }

      state = state.copyWith(isReSearching: false, reSearchError: '重新搜索失败: $e');
    }
  }

  /// 清除搜索结果
  void clear() {
    // 递增请求序号，使任何进行中的搜索请求失效
    _searchRequestId++;
    state = const EnterpriseSearchState();
  }
}

// ==================== WebView State ====================

/// 详情加载状态
enum DetailFetchStatus {
  /// 未开始
  idle,

  /// 加载中
  loading,

  /// 加载成功
  success,

  /// 加载失败
  failed,
}

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
    this.detailFetchStatus = DetailFetchStatus.idle,
    this.detailFetchError,
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

  /// 详情加载状态
  final DetailFetchStatus detailFetchStatus;

  /// 详情加载错误信息
  final String? detailFetchError;

  bool get hasError => error != null;
  bool get hasPending => pendingEnterprise != null;
  bool get isLoadingDetail => detailFetchStatus == DetailFetchStatus.loading;
  bool get detailFetchFailed => detailFetchStatus == DetailFetchStatus.failed;

  EnterpriseWebState copyWith({
    int? progress,
    bool? isLoading,
    bool? sessionExpired,
    Enterprise? pendingEnterprise,
    bool? isImporting,
    EnterpriseImportResult? importResult,
    String? error,
    DetailFetchStatus? detailFetchStatus,
    String? detailFetchError,
    bool clearPending = false,
    bool clearError = false,
    bool clearResult = false,
    bool clearDetailError = false,
  }) {
    return EnterpriseWebState(
      progress: progress ?? this.progress,
      isLoading: isLoading ?? this.isLoading,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      pendingEnterprise: clearPending
          ? null
          : (pendingEnterprise ?? this.pendingEnterprise),
      isImporting: isImporting ?? this.isImporting,
      importResult: clearResult ? null : (importResult ?? this.importResult),
      error: clearError ? null : (error ?? this.error),
      detailFetchStatus: detailFetchStatus ?? this.detailFetchStatus,
      detailFetchError: clearDetailError
          ? null
          : (detailFetchError ?? this.detailFetchError),
    );
  }
}

// ==================== WebView Provider ====================

/// WebView 状态 Provider
final enterpriseWebProvider =
    StateNotifierProvider<EnterpriseWebNotifier, EnterpriseWebState>((ref) {
      return EnterpriseWebNotifier(ref.read(enterpriseRepositoryProvider), ref);
    });

/// WebView 状态 Notifier
class EnterpriseWebNotifier extends StateNotifier<EnterpriseWebState> {
  EnterpriseWebNotifier(this._repository, this._ref)
    : super(const EnterpriseWebState());

  final EnterpriseRepository _repository;
  final Ref _ref;

  /// 更新加载进度
  void setProgress(int progress) {
    state = state.copyWith(progress: progress, isLoading: progress < 100);
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
    if (enterprise == null) {
      debugPrint('[EnterpriseWebNotifier] importPending: pendingEnterprise 为空');
      return false;
    }

    debugPrint(
      '[EnterpriseWebNotifier] importPending: 开始导入 ${enterprise.name}',
    );
    state = state.copyWith(isImporting: true, clearError: true);

    try {
      debugPrint(
        '[EnterpriseWebNotifier] importPending: 调用 repository.importEnterprise()',
      );
      final result = await _repository.importEnterprise(
        enterprise: enterprise,
        forceOverwrite: forceOverwrite,
      );

      debugPrint(
        '[EnterpriseWebNotifier] importPending: 结果 status=${result.status}, isSuccess=${result.isSuccess}, message=${result.message}',
      );

      state = state.copyWith(
        isImporting: false,
        importResult: result,
        clearPending: result.isSuccess,
      );

      return result.isSuccess;
    } catch (e, stackTrace) {
      debugPrint('[EnterpriseWebNotifier] importPending: 异常 $e');
      debugPrint('[EnterpriseWebNotifier] importPending: 堆栈 $stackTrace');
      state = state.copyWith(isImporting: false, error: '导入失败: $e');
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

  /// 获取企业详情
  ///
  /// 如果企业需要从详情页获取完整信息（needsDetailFetch），
  /// 则通过 WebView 导航到详情页并执行 JS 提取脚本。
  Future<void> fetchEnterpriseDetail() async {
    final enterprise = state.pendingEnterprise;
    if (enterprise == null) {
      debugPrint('[详情获取] pendingEnterprise 为空，跳过');
      return;
    }

    // 检查是否需要获取详情
    if (!enterprise.needsDetailFetch) {
      debugPrint('[详情获取] 企业 ${enterprise.name} 不需要获取详情');
      state = state.copyWith(detailFetchStatus: DetailFetchStatus.success);
      return;
    }

    // 检查是否有详情页 URL
    final detailUrl = enterprise.detailUrl;
    if (detailUrl.isEmpty) {
      debugPrint('[详情获取] 企业 ${enterprise.name} 没有详情页 URL');
      state = state.copyWith(
        detailFetchStatus: DetailFetchStatus.failed,
        detailFetchError: '无法获取详情：缺少详情页链接',
      );
      return;
    }

    // 获取 WebView 控制器
    final controller = _ref.read(webViewControllerProvider);
    if (controller == null) {
      debugPrint('[详情获取] WebView 控制器不可用');
      state = state.copyWith(
        detailFetchStatus: DetailFetchStatus.failed,
        detailFetchError: '请先打开企查查页面',
      );
      return;
    }

    debugPrint('[详情获取] 开始获取企业 ${enterprise.name} 的详情');
    debugPrint('[详情获取] 详情页 URL: $detailUrl');

    state = state.copyWith(
      detailFetchStatus: DetailFetchStatus.loading,
      clearDetailError: true,
    );

    try {
      // 导航到详情页
      await controller.loadUrl(urlRequest: URLRequest(url: WebUri(detailUrl)));

      // 等待页面加载完成
      await _waitForPageLoad(controller, const Duration(seconds: 10));

      // 获取数据源的提取脚本
      final dataSource = _ref.read(enterpriseDataSourceProvider);
      final extractJs = dataSource.extractDataJs;

      // 注入并执行提取脚本
      await controller.evaluateJavascript(source: extractJs);

      // 执行提取函数
      final resultJson = await controller.evaluateJavascript(
        source: 'JSON.stringify(window.__extractEnterpriseData())',
      );

      if (!mounted) return;

      if (resultJson == null || resultJson == 'null') {
        debugPrint('[详情获取] 提取脚本返回空结果');
        state = state.copyWith(
          detailFetchStatus: DetailFetchStatus.failed,
          detailFetchError: '无法从详情页提取数据',
        );
        return;
      }

      // 解析结果
      final jsonStr = resultJson is String ? resultJson : resultJson.toString();
      // 移除可能的引号包裹
      final cleanJson = jsonStr.startsWith('"') && jsonStr.endsWith('"')
          ? jsonStr.substring(1, jsonStr.length - 1).replaceAll(r'\"', '"')
          : jsonStr;

      debugPrint(
        '[详情获取] 提取结果: ${cleanJson.substring(0, cleanJson.length > 200 ? 200 : cleanJson.length)}...',
      );

      final detailMap = jsonDecode(cleanJson) as Map<String, dynamic>;
      final detailEnterprise = Enterprise.fromJson(detailMap);

      // 合并详情到待导入企业（保留原有的基本信息，补充详情）
      final mergedEnterprise = enterprise.copyWith(
        creditCode: detailEnterprise.creditCode.isNotEmpty
            ? detailEnterprise.creditCode
            : enterprise.creditCode,
        legalPerson: detailEnterprise.legalPerson.isNotEmpty
            ? detailEnterprise.legalPerson
            : enterprise.legalPerson,
        registeredCapital: detailEnterprise.registeredCapital.isNotEmpty
            ? detailEnterprise.registeredCapital
            : enterprise.registeredCapital,
        establishDate: detailEnterprise.establishDate.isNotEmpty
            ? detailEnterprise.establishDate
            : enterprise.establishDate,
        status: detailEnterprise.status.isNotEmpty
            ? detailEnterprise.status
            : enterprise.status,
        address: detailEnterprise.address.isNotEmpty
            ? detailEnterprise.address
            : enterprise.address,
        industry: detailEnterprise.industry.isNotEmpty
            ? detailEnterprise.industry
            : enterprise.industry,
        businessScope: detailEnterprise.businessScope.isNotEmpty
            ? detailEnterprise.businessScope
            : enterprise.businessScope,
        phone: detailEnterprise.phone.isNotEmpty
            ? detailEnterprise.phone
            : enterprise.phone,
        email: detailEnterprise.email.isNotEmpty
            ? detailEnterprise.email
            : enterprise.email,
        website: detailEnterprise.website.isNotEmpty
            ? detailEnterprise.website
            : enterprise.website,
      );

      debugPrint(
        '[详情获取] 合并后企业信息: phone=${mergedEnterprise.phone}, address=${mergedEnterprise.address}',
      );

      state = state.copyWith(
        pendingEnterprise: mergedEnterprise,
        detailFetchStatus: DetailFetchStatus.success,
      );

      debugPrint('[详情获取] 详情获取成功');
    } catch (e) {
      debugPrint('[详情获取] 获取详情失败: $e');
      if (!mounted) return;

      state = state.copyWith(
        detailFetchStatus: DetailFetchStatus.failed,
        detailFetchError: '获取详情失败: ${e.toString()}',
      );
    }
  }

  /// 等待 WebView 页面加载完成
  Future<void> _waitForPageLoad(
    InAppWebViewController controller,
    Duration timeout,
  ) async {
    final startTime = DateTime.now();
    const pollInterval = Duration(milliseconds: 300);

    while (DateTime.now().difference(startTime) < timeout) {
      try {
        final readyState = await controller.evaluateJavascript(
          source: 'document.readyState',
        );
        if (readyState == 'complete' || readyState == '"complete"') {
          // 额外等待 500ms 让 JS 渲染完成
          await Future.delayed(const Duration(milliseconds: 500));
          return;
        }
      } catch (_) {
        // 忽略错误，继续轮询
      }
      await Future.delayed(pollInterval);
    }
    debugPrint('[详情获取] 等待页面加载超时，继续执行');
  }

  /// 重置详情加载状态
  void resetDetailFetchStatus() {
    state = state.copyWith(
      detailFetchStatus: DetailFetchStatus.idle,
      clearDetailError: true,
    );
  }
}
