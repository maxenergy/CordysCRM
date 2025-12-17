import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/enterprise.dart';
import '../../domain/repositories/enterprise_repository.dart';
import '../../presentation/features/enterprise/enterprise_provider.dart';

/// 企业仓库实现
///
/// 调用后端 API 实现企业导入，使用安全存储管理 Cookie
class EnterpriseRepositoryImpl implements EnterpriseRepository {
  EnterpriseRepositoryImpl({
    required Dio dio,
    FlutterSecureStorage? secureStorage,
    String basePath = '/api/enterprise',
    Ref? ref,
  })  : _dio = dio,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _basePath = basePath,
        _ref = ref;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final String _basePath;
  final Ref? _ref;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  static const _cookieKey = 'aiqicha_cookies';
  static const _userAgentKey = 'aiqicha_user_agent';

  @override
  Future<EnterpriseSearchResult> searchLocal({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    _logger.d('搜索企业(本地): $keyword, page=$page, pageSize=$pageSize');

    try {
      // 调用后端 /search-local 端点，只查本地数据库，不调用爱企查
      final response = await _dio.get(
        '$_basePath/search-local',
        queryParameters: {
          'keyword': keyword,
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        Map<String, dynamic> searchData;
        if (responseData.containsKey('code') &&
            responseData.containsKey('data')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            final message =
                responseData['message'] as String? ?? '服务器错误 (code: $code)';
            _logger.w('搜索(本地)失败: code=$code, message=$message');
            return EnterpriseSearchResult.error(message);
          }
          searchData = responseData['data'] as Map<String, dynamic>? ?? {};
        } else {
          searchData = responseData;
        }

        final parsed = EnterpriseSearchResult.fromJson(searchData);
        
        // 如果后端返回 success: false，直接返回错误结果
        // 确保失败时 items=[], total=0，避免传递无效数据
        if (!parsed.success) {
          _logger.w('搜索(本地)失败: keyword=$keyword, message=${parsed.message ?? "未知错误"}');
          return EnterpriseSearchResult.error(parsed.message ?? '搜索失败');
        }
        
        final items = parsed.items
            .map((e) => e.source.isEmpty ? e.copyWith(source: 'local') : e)
            .toList();

        final result = EnterpriseSearchResult(
          success: parsed.success,
          items: items,
          total: parsed.total,
          message: parsed.message,
        );

        _logger.i('搜索(本地)结果: ${result.items.length} 条, 总计 ${result.total} 条');
        return result;
      }

      return EnterpriseSearchResult.error('搜索(本地)请求失败: ${response.statusCode}');
    } on DioException catch (e) {
      _logger.e('搜索企业(本地)失败: ${e.message}');
      if (e.response?.statusCode == 401) {
        return EnterpriseSearchResult.error('请先登录');
      }
      final errorData = e.response?.data;
      if (errorData is Map<String, dynamic>) {
        final message = errorData['message'] as String? ??
            (errorData['data'] as Map<String, dynamic>?)?['message'] as String?;
        if (message != null && message.isNotEmpty) {
          return EnterpriseSearchResult.error(message);
        }
      }
      return EnterpriseSearchResult.error('搜索(本地)失败: ${e.message ?? '网络错误'}');
    } catch (e) {
      _logger.e('搜索企业(本地)异常: $e');
      return EnterpriseSearchResult.error('搜索(本地)失败: $e');
    }
  }

  @override
  Future<EnterpriseSearchResult> searchAiqicha({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    _logger.d('搜索企业(爱企查-WebView导航): $keyword, page=$page, pageSize=$pageSize');

    // 检查是否有 ProviderRef
    if (_ref == null) {
      _logger.e('[WebView] ProviderRef 未设置，无法使用 WebView 搜索');
      return EnterpriseSearchResult.error('内部错误：无法访问 WebView');
    }

    // 获取 WebView 控制器
    final controller = _ref.read(webViewControllerProvider);
    if (controller == null) {
      _logger.w('[WebView] WebView 控制器未初始化，请先打开爱企查页面');
      return EnterpriseSearchResult.error('请先打开爱企查页面');
    }

    try {
      // 创建 Completer 用于等待 JS 回调
      final completer = Completer<List<Map<String, String>>>();
      _ref.read(aiqichaSearchCompleterProvider.notifier).state = completer;

      // 构建搜索 URL
      final searchUrl = 'https://aiqicha.baidu.com/s?q=${Uri.encodeComponent(keyword)}';
      _logger.d('[WebView] 导航到搜索页面: $searchUrl');

      // 先注入一个标记，用于检测页面是否已加载完成
      // 然后导航到搜索页面
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri(searchUrl)),
      );

      // 等待页面加载完成并提取数据
      // 使用轮询方式检查页面状态，最多等待 30 秒
      const maxWaitTime = Duration(seconds: 30);
      const pollInterval = Duration(milliseconds: 500);
      final startTime = DateTime.now();
      
      while (DateTime.now().difference(startTime) < maxWaitTime) {
        await Future.delayed(pollInterval);
        
        // 检查页面是否加载完成
        final readyState = await controller.evaluateJavascript(
          source: 'document.readyState',
        );
        
        if (readyState != 'complete') {
          continue;
        }
        
        // 检查当前 URL 是否是搜索结果页
        final currentUrl = await controller.getUrl();
        final urlStr = currentUrl?.toString() ?? '';
        
        if (!urlStr.contains('aiqicha.baidu.com')) {
          _logger.w('[WebView] 页面被重定向到非爱企查域名: $urlStr');
          // 可能被重定向到登录页
          if (urlStr.contains('passport.baidu.com') || urlStr.contains('login')) {
            return EnterpriseSearchResult.error('请先在爱企查页面登录');
          }
          continue;
        }
        
        // 执行 JavaScript 提取搜索结果
        final jsCode = '''
(function() {
  try {
    // 检查是否需要验证
    const pageText = document.body.innerText || '';
    if (pageText.includes('安全验证') || pageText.includes('请输入验证码') || 
        pageText.includes('滑动验证') || document.querySelector('.vcode-spin-card')) {
      window.flutter_inappwebview.callHandler('onAiqichaSearchError', '需要滑块验证，请在当前页面完成验证后重试');
      return;
    }
    
    if (pageText.includes('请登录') || pageText.includes('百度帐号登录')) {
      window.flutter_inappwebview.callHandler('onAiqichaSearchError', '请先登录爱企查');
      return;
    }
    
    // 查找企业链接 - 搜索结果页的企业链接
    const links = document.querySelectorAll('a[href*="pid="], a[href*="company_detail"]');
    const seen = new Set();
    const results = [];
    
    const pidRegex = /pid=([^&]+)/;
    
    for (const link of links) {
      const href = link.getAttribute('href');
      if (!href) continue;
      
      const pidMatch = href.match(pidRegex);
      if (!pidMatch) continue;
      
      const pid = pidMatch[1].trim();
      if (!pid || seen.has(pid)) continue;
      
      // 获取企业名称 - 优先从链接文本获取，过滤掉导航链接
      let name = link.textContent.trim();
      
      // 过滤无效结果
      if (!name || name.length > 100 || name.length < 2) continue;
      // 过滤掉明显不是企业名称的文本
      if (name.includes('查看更多') || name.includes('首页') || name.includes('登录')) continue;
      
      seen.add(pid);
      results.push({ pid: pid, name: name });
    }
    
    // 如果没有找到结果，可能是页面结构不同，尝试其他选择器
    if (results.length === 0) {
      // 尝试查找搜索结果列表项
      const items = document.querySelectorAll('.search-result-item, .company-item, [class*="result"]');
      for (const item of items) {
        const link = item.querySelector('a[href*="pid="]');
        if (!link) continue;
        
        const href = link.getAttribute('href');
        const pidMatch = href.match(pidRegex);
        if (!pidMatch) continue;
        
        const pid = pidMatch[1].trim();
        if (!pid || seen.has(pid)) continue;
        
        const nameEl = item.querySelector('.company-name, .title, h3, h2');
        const name = nameEl ? nameEl.textContent.trim() : link.textContent.trim();
        
        if (!name || name.length > 100 || name.length < 2) continue;
        
        seen.add(pid);
        results.push({ pid: pid, name: name });
      }
    }
    
    window.flutter_inappwebview.callHandler('onAiqichaSearchResult', JSON.stringify(results));
  } catch (e) {
    window.flutter_inappwebview.callHandler('onAiqichaSearchError', '提取数据异常: ' + e.toString());
  }
})();
''';

        _logger.d('[WebView] 页面加载完成，执行数据提取...');
        await controller.evaluateJavascript(source: jsCode);
        
        // 跳出轮询循环，等待 JS 回调
        break;
      }

      // 等待结果，设置超时
      final rawResults = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.e('[WebView] 等待搜索结果超时');
          throw TimeoutException('搜索超时，请重试');
        },
      );

      _logger.d('[WebView] 收到 ${rawResults.length} 个搜索结果');

      // 转换为 Enterprise 对象
      final allItems = rawResults.map((item) {
        return Enterprise(
          id: item['pid'] ?? '',
          name: item['name'] ?? '',
          source: 'iqicha',
        );
      }).where((e) => e.id.isNotEmpty && e.name.isNotEmpty).toList();

      // 简单分页切片
      final start = (page - 1) * pageSize;
      final items = start >= allItems.length
          ? <Enterprise>[]
          : allItems.skip(start).take(pageSize).toList();

      _logger.i('搜索(爱企查-WebView导航)成功: 返回 ${items.length} 条, 总计 ${allItems.length} 条');

      return EnterpriseSearchResult(
        success: true,
        items: items,
        total: allItems.length,
      );
    } on TimeoutException catch (e) {
      _logger.e('[WebView] 搜索超时: $e');
      return EnterpriseSearchResult.error('搜索超时，请重试');
    } catch (e) {
      _logger.e('[WebView] 搜索异常: $e');
      return EnterpriseSearchResult.error('$e');
    }
  }

  /// Legacy：会调用后端 /api/enterprise/search（可能触发"服务端查爱企查"）
  /// 新架构请坚持 searchLocal -> searchAiqicha（客户端直连）
  @Deprecated('Use searchLocal() then searchAiqicha() instead')
  @override
  Future<EnterpriseSearchResult> searchEnterprise({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    _logger.d('[Legacy] 搜索企业: $keyword, page=$page, pageSize=$pageSize');

    try {
      final response = await _dio.get(
        '$_basePath/search',
        queryParameters: {
          'keyword': keyword,
          'page': page,
          'pageSize': pageSize,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // 后端使用 ResultHolder 包装响应，格式为 { code, message, data }
        // 成功码为 100200（不是 HTTP 200），需要从 data 字段中提取实际的搜索结果
        Map<String, dynamic> searchData;
        if (responseData.containsKey('code') && responseData.containsKey('data')) {
          // ResultHolder 包装格式
          final code = responseData['code'] as int?;
          // 后端成功码是 100200，不是 200
          if (code != null && code != 100200) {
            final message = responseData['message'] as String? ?? '服务器错误 (code: $code)';
            _logger.w('搜索失败: code=$code, message=$message');
            return EnterpriseSearchResult.error(message);
          }
          searchData = responseData['data'] as Map<String, dynamic>? ?? {};
        } else {
          // 直接返回格式（兼容）
          searchData = responseData;
        }
        
        final result = EnterpriseSearchResult.fromJson(searchData);
        _logger.i('搜索结果: ${result.items.length} 条, 总计 ${result.total} 条');
        return result;
      }

      return EnterpriseSearchResult.error('搜索请求失败: ${response.statusCode}');
    } on DioException catch (e) {
      _logger.e('搜索企业失败: ${e.message}');
      
      // 处理特定错误
      if (e.response?.statusCode == 401) {
        return EnterpriseSearchResult.error('请先登录');
      }
      
      final errorData = e.response?.data;
      if (errorData is Map<String, dynamic>) {
        // 尝试从 ResultHolder 格式中提取错误信息
        final message = errorData['message'] as String? ?? 
                        (errorData['data'] as Map<String, dynamic>?)?['message'] as String?;
        if (message != null && message.isNotEmpty) {
          return EnterpriseSearchResult.error(message);
        }
      }
      
      return EnterpriseSearchResult.error('搜索失败: ${e.message ?? '网络错误'}');
    } catch (e) {
      _logger.e('搜索企业异常: $e');
      return EnterpriseSearchResult.error('搜索失败: $e');
    }
  }

  @override
  Future<EnterpriseImportResult> importEnterprise({
    required Enterprise enterprise,
    bool forceOverwrite = false,
  }) async {
    _logger.d('导入企业: ${enterprise.name}');

    try {
      final response = await _dio.post(
        '$_basePath/import',
        data: {
          ...enterprise.toJson(),
          'forceOverwrite': forceOverwrite,
        },
      );

      if (response.statusCode == 200) {
        final result = EnterpriseImportResult.fromJson(
          response.data as Map<String, dynamic>,
        );
        _logger.i('导入结果: ${result.status}');
        return result;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '导入失败: ${response.statusCode}',
      );
    } on DioException catch (e) {
      _logger.e('导入企业失败: ${e.message}');

      // 处理冲突响应
      if (e.response?.statusCode == 409) {
        return EnterpriseImportResult.fromJson(
          e.response?.data as Map<String, dynamic>? ?? {'status': 'conflict'},
        );
      }

      rethrow;
    }
  }

  @override
  Future<void> saveCookies(Map<String, String> cookies) async {
    _logger.d('保存 Cookie: ${cookies.length} 个');

    try {
      final jsonStr = jsonEncode(cookies);
      await _secureStorage.write(key: _cookieKey, value: jsonStr);
      _logger.i('Cookie 保存成功');
    } catch (e) {
      _logger.e('保存 Cookie 失败: $e');
    }
  }

  @override
  Future<Map<String, String>> loadCookies() async {
    _logger.d('加载 Cookie');

    try {
      final jsonStr = await _secureStorage.read(key: _cookieKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return {};
      }

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      final cookies = decoded.map((k, v) => MapEntry(k, v.toString()));

      // 将 Cookie 设置到 WebView CookieManager（区分域名）
      for (final entry in cookies.entries) {
        final key = entry.key;
        final value = entry.value;

        // 跳过空值的 Cookie，flutter_inappwebview 要求 value 不能为空
        if (value.isEmpty) {
          _logger.d('跳过空值 Cookie: $key');
          continue;
        }

        if (key.startsWith('aiqicha_')) {
          final name = key.substring('aiqicha_'.length);
          await CookieManager.instance().setCookie(
            url: WebUri('https://aiqicha.baidu.com'),
            name: name,
            value: value,
            domain: '.baidu.com',
          );
        } else if (key.startsWith('passport_')) {
          final name = key.substring('passport_'.length);
          await CookieManager.instance().setCookie(
            url: WebUri('https://passport.baidu.com'),
            name: name,
            value: value,
            domain: '.baidu.com',
          );
        } else {
          // 兼容旧格式
          await CookieManager.instance().setCookie(
            url: WebUri('https://aiqicha.baidu.com'),
            name: key,
            value: value,
            domain: '.baidu.com',
          );
        }
      }

      _logger.i('Cookie 加载成功: ${cookies.length} 个');
      return cookies;
    } catch (e) {
      _logger.e('加载 Cookie 失败: $e');
      return {};
    }
  }

  @override
  Future<void> clearCookies() async {
    _logger.d('清除 Cookie 和 User-Agent');

    try {
      await _secureStorage.delete(key: _cookieKey);
      await _secureStorage.delete(key: _userAgentKey); // 同时清理 User-Agent
      // 清除两个域名的 Cookie
      await CookieManager.instance().deleteCookies(
        url: WebUri('https://aiqicha.baidu.com'),
      );
      await CookieManager.instance().deleteCookies(
        url: WebUri('https://passport.baidu.com'),
      );
      _logger.i('Cookie 和 User-Agent 清除成功');
    } catch (e) {
      _logger.e('清除 Cookie 失败: $e');
    }
  }

  @override
  Future<void> saveUserAgent(String userAgent) async {
    _logger.d('保存 User-Agent: ${userAgent.substring(0, userAgent.length > 50 ? 50 : userAgent.length)}...');

    try {
      await _secureStorage.write(key: _userAgentKey, value: userAgent);
      _logger.i('User-Agent 保存成功');
    } catch (e) {
      _logger.e('保存 User-Agent 失败: $e');
    }
  }

  @override
  Future<String?> loadUserAgent() async {
    try {
      return await _secureStorage.read(key: _userAgentKey);
    } catch (e) {
      _logger.e('加载 User-Agent 失败: $e');
      return null;
    }
  }

}

/// Mock 企业仓库实现
///
/// 用于开发和测试
class MockEnterpriseRepository implements EnterpriseRepository {
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final Map<String, String> _cookies = {};

  @override
  Future<EnterpriseSearchResult> searchLocal({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    final result =
        await searchEnterprise(keyword: keyword, page: page, pageSize: pageSize);
    return EnterpriseSearchResult(
      success: result.success,
      items: result.items
          .map((e) => e.copyWith(source: e.source.isEmpty ? 'local' : e.source))
          .toList(),
      total: result.total,
      message: result.message,
    );
  }

  @override
  Future<EnterpriseSearchResult> searchAiqicha({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    final result =
        await searchEnterprise(keyword: keyword, page: page, pageSize: pageSize);
    return EnterpriseSearchResult(
      success: result.success,
      items: result.items
          .map((e) => e.copyWith(source: e.source.isEmpty ? 'iqicha' : e.source))
          .toList(),
      total: result.total,
      message: result.message,
    );
  }

  @override
  Future<EnterpriseSearchResult> searchEnterprise({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    _logger.d('[Mock] 搜索企业: $keyword');

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 模拟搜索结果
    final mockData = [
      const Enterprise(
        id: 'ent_001',
        name: '阿里巴巴集团控股有限公司',
        creditCode: '91330100799655058B',
        legalPerson: '蔡崇信',
        status: '存续',
        industry: '互联网和相关服务',
      ),
      const Enterprise(
        id: 'ent_002',
        name: '腾讯科技（深圳）有限公司',
        creditCode: '91440300708461136T',
        legalPerson: '马化腾',
        status: '存续',
        industry: '软件和信息技术服务业',
      ),
      const Enterprise(
        id: 'ent_003',
        name: '华为技术有限公司',
        creditCode: '91440300279583285X',
        legalPerson: '任正非',
        status: '存续',
        industry: '通信设备制造',
      ),
      const Enterprise(
        id: 'ent_004',
        name: '字节跳动有限公司',
        creditCode: '91110108MA001LXLXJ',
        legalPerson: '张利东',
        status: '存续',
        industry: '互联网和相关服务',
      ),
      const Enterprise(
        id: 'ent_005',
        name: '小米科技有限责任公司',
        creditCode: '91110108551385082Q',
        legalPerson: '雷军',
        status: '存续',
        industry: '计算机、通信和其他电子设备制造业',
      ),
    ];

    final results = mockData
        .where((e) => e.name.contains(keyword) || e.creditCode.contains(keyword))
        .toList();

    return EnterpriseSearchResult(
      success: true,
      items: results,
      total: results.length,
    );
  }

  @override
  Future<EnterpriseImportResult> importEnterprise({
    required Enterprise enterprise,
    bool forceOverwrite = false,
  }) async {
    _logger.d('[Mock] 导入企业: ${enterprise.name}');

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 800));

    // 模拟导入成功
    return EnterpriseImportResult(
      status: 'success',
      customerId: 'cust_${DateTime.now().millisecondsSinceEpoch}',
      message: '导入成功',
    );
  }

  @override
  Future<void> saveCookies(Map<String, String> cookies) async {
    _logger.d('[Mock] 保存 Cookie: ${cookies.length} 个');
    _cookies.addAll(cookies);
  }

  @override
  Future<Map<String, String>> loadCookies() async {
    _logger.d('[Mock] 加载 Cookie');
    return Map.from(_cookies);
  }

  @override
  Future<void> clearCookies() async {
    _logger.d('[Mock] 清除 Cookie');
    _cookies.clear();
  }

  String? _userAgent;

  @override
  Future<void> saveUserAgent(String userAgent) async {
    _logger.d('[Mock] 保存 User-Agent');
    _userAgent = userAgent;
  }

  @override
  Future<String?> loadUserAgent() async {
    _logger.d('[Mock] 加载 User-Agent');
    return _userAgent;
  }
}
