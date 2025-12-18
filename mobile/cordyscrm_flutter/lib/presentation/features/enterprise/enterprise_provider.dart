import 'dart:async';
import 'dart:convert';

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
final enterpriseDataSourceProvider = Provider<EnterpriseDataSourceInterface>(
  (ref) {
    final type = ref.watch(enterpriseDataSourceTypeProvider);
    return switch (type) {
      EnterpriseDataSourceType.qcc => ref.watch(qccDataSourceProvider),
      EnterpriseDataSourceType.iqicha => ref.watch(aiqichaDataSourceProvider),
      EnterpriseDataSourceType.unknown => ref.watch(qccDataSourceProvider),
    };
  },
);

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
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);

/// 爱企查搜索结果 Completer Provider
///
/// 用于 WebView JS 回调和 Repository 之间的异步通信
final aiqichaSearchCompleterProvider = StateProvider<Completer<List<Map<String, String>>>?>((ref) => null);

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
/// 包含本地数据源和爱企查数据源的示例
const List<Enterprise> _mockEnterprises = [
  // 本地数据源
  Enterprise(
    id: 'local_10001',
    name: 'CordysCRM 示例科技有限公司',
    creditCode: '91310115MA1K3X0X1A',
    legalPerson: '张三',
    registeredCapital: '1000万人民币',
    establishDate: '2016-05-18',
    status: '存续',
    address: '上海市浦东新区示例路 88 号',
    industry: '软件和信息技术服务业',
    businessScope: '企业管理软件研发；信息技术咨询服务；系统集成服务',
    phone: '021-88886666',
    email: 'contact@cordyscrm.example',
    website: 'https://cordyscrm.example',
    source: 'local',
  ),
  Enterprise(
    id: 'local_10002',
    name: '广州启航贸易有限公司',
    creditCode: '91440101MA5D1A2B3C',
    legalPerson: '李四',
    registeredCapital: '500万人民币',
    establishDate: '2019-03-12',
    status: '在业',
    address: '广州市天河区示例大道 66 号',
    industry: '批发和零售业',
    businessScope: '日用百货批发零售；供应链管理；国内贸易代理',
    phone: '020-66668888',
    email: 'sales@qihang.example',
    website: 'https://qihang.example',
    source: 'local',
  ),
  // 爱企查数据源
  Enterprise(
    id: 'iqicha_90001',
    name: '北京星云数据技术有限公司',
    creditCode: '91110108MA01XYZ123',
    legalPerson: '王五',
    registeredCapital: '2000万人民币',
    establishDate: '2017-11-06',
    status: '存续',
    address: '北京市海淀区示例科技园 1 号楼',
    industry: '科学研究和技术服务业',
    businessScope: '数据处理与存储服务；技术开发；技术转让；技术咨询',
    phone: '010-99990000',
    email: 'bd@nebula.example',
    website: 'https://nebula.example',
    source: 'iqicha',
  ),
  Enterprise(
    id: 'iqicha_90002',
    name: '深圳市云启智能有限公司',
    creditCode: '91440300MA5FABCDE9',
    legalPerson: '赵六',
    registeredCapital: '3000万人民币',
    establishDate: '2020-07-21',
    status: '存续',
    address: '深圳市南山区示例创新中心 20 层',
    industry: '制造业',
    businessScope: '智能硬件研发与销售；物联网应用；软件开发与系统集成',
    phone: '0755-12345678',
    email: 'support@yunqi.example',
    website: 'https://yunqi.example',
    source: 'iqicha',
  ),
  Enterprise(
    id: 'iqicha_90003',
    name: '杭州爱企查信息服务有限公司',
    creditCode: '91330106MA2H0Q1W2E',
    legalPerson: '钱七',
    registeredCapital: '800万人民币',
    establishDate: '2018-02-09',
    status: '存续',
    address: '杭州市西湖区示例软件园 A 座',
    industry: '信息传输、软件和信息技术服务业',
    businessScope: '企业信息咨询；数据服务；互联网信息服务',
    phone: '0571-88001122',
    email: 'hello@iqicha.example',
    website: 'https://iqicha.example',
    source: 'iqicha',
  ),
];

// ==================== Search State ====================

/// 企业搜索数据来源
enum EnterpriseSearchDataSource {
  local,
  iqicha,
  qcc,
  mixed,
}

/// 企业搜索状态
class EnterpriseSearchState {
  const EnterpriseSearchState({
    this.isSearching = false,
    this.results = const [],
    this.total = 0,
    this.error,
    this.keyword = '',
    this.dataSource,
  });

  final bool isSearching;
  final List<Enterprise> results;
  final int total;
  final String? error;
  final String keyword;
  final EnterpriseSearchDataSource? dataSource;

  bool get hasError => error != null;
  bool get hasResults => results.isNotEmpty;

  String? get dataSourceLabel {
    return switch (dataSource) {
      EnterpriseSearchDataSource.local => 'CRM 本地库',
      EnterpriseSearchDataSource.iqicha => '爱企查',
      EnterpriseSearchDataSource.qcc => '企查查',
      EnterpriseSearchDataSource.mixed => '本地 + 外部数据源',
      _ => null,
    };
  }

  EnterpriseSearchState copyWith({
    bool? isSearching,
    List<Enterprise>? results,
    int? total,
    String? error,
    String? keyword,
    EnterpriseSearchDataSource? dataSource,
    bool clearError = false,
    bool clearDataSource = false,
  }) {
    return EnterpriseSearchState(
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
      keyword: keyword ?? this.keyword,
      dataSource: clearDataSource ? null : (dataSource ?? this.dataSource),
    );
  }
}

/// 企业搜索 Provider
final enterpriseSearchProvider =
    StateNotifierProvider<EnterpriseSearchNotifier, EnterpriseSearchState>(
        (ref) {
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
      keyword: trimmedKeyword,
      clearError: true,
      clearDataSource: true,
    );

    try {
      // 演示模式：返回模拟数据
      if (isMockMode) {
        await _searchMockData(trimmedKeyword, currentRequestId);
        return;
      }

      // 真实模式：先查 CRM 本地库（后端只查本地数据库，不调用爱企查）
      final localResult = await _repository.searchLocal(keyword: trimmedKeyword);

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
        final iqichaResult =
            await _repository.searchAiqicha(keyword: trimmedKeyword);

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
        final qccResult =
            await _repository.searchQichacha(keyword: trimmedKeyword);

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

  /// 清除搜索结果
  void clear() {
    // 递增请求序号，使任何进行中的搜索请求失效
    _searchRequestId++;
    state = const EnterpriseSearchState();
  }
}

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
