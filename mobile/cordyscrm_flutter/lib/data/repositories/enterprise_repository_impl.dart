import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../domain/entities/enterprise.dart';
import '../../domain/repositories/enterprise_repository.dart';

/// 企业仓库实现
///
/// 调用后端 API 实现企业导入，使用安全存储管理 Cookie
class EnterpriseRepositoryImpl implements EnterpriseRepository {
  EnterpriseRepositoryImpl({
    required Dio dio,
    FlutterSecureStorage? secureStorage,
    String basePath = '/api/enterprise',
  })  : _dio = dio,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _basePath = basePath;

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final String _basePath;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  static const _cookieKey = 'aiqicha_cookies';

  @override
  Future<EnterpriseSearchResult> searchLocal({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    _logger.d('搜索企业(本地): $keyword, page=$page, pageSize=$pageSize');

    try {
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
    _logger.d('搜索企业(爱企查): $keyword, page=$page, pageSize=$pageSize');

    try {
      final cookies = await _readCookiesFromStorageOnly();
      if (cookies.isEmpty) {
        return EnterpriseSearchResult.error('未检测到爱企查 Cookie，请先通过 WebView 登录后重试');
      }

      final cookieHeader = _buildAiqichaCookieHeader(cookies);
      if (cookieHeader.isEmpty) {
        return EnterpriseSearchResult.error('爱企查 Cookie 为空或无效，请重新登录后重试');
      }

      // 创建独立的 Dio 实例访问爱企查，避免使用 CRM 后端的拦截器
      final aiqichaDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await aiqichaDio.get(
        'https://aiqicha.baidu.com/s',
        queryParameters: {'q': keyword},
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: true,
          headers: {
            'Cookie': cookieHeader,
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          },
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        return EnterpriseSearchResult.error('爱企查请求失败: ${response.statusCode}');
      }

      final html = response.data.toString();

      // 检测是否被重定向到验证码页面
      if (html.contains('wappass') || html.contains('验证码')) {
        return EnterpriseSearchResult.error('爱企查需要验证码验证，请在 WebView 中完成验证后重试');
      }

      final allItems = _parseAiqichaSearchHtml(html);

      // 简单分页切片
      final start = (page - 1) * pageSize;
      final items = start >= allItems.length
          ? <Enterprise>[]
          : allItems.skip(start).take(pageSize).toList();

      _logger.i('搜索(爱企查)结果: ${items.length} 条, 总计 ${allItems.length} 条');

      return EnterpriseSearchResult(
        success: true,
        items: items,
        total: allItems.length,
      );
    } on DioException catch (e) {
      _logger.e('搜索企业(爱企查)失败: ${e.message}');
      return EnterpriseSearchResult.error('爱企查搜索失败: ${e.message ?? '网络错误'}');
    } catch (e) {
      _logger.e('搜索企业(爱企查)异常: $e');
      return EnterpriseSearchResult.error('爱企查搜索失败: $e');
    }
  }

  @override
  Future<EnterpriseSearchResult> searchEnterprise({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    _logger.d('搜索企业: $keyword, page=$page, pageSize=$pageSize');

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
    _logger.d('清除 Cookie');

    try {
      await _secureStorage.delete(key: _cookieKey);
      // 清除两个域名的 Cookie
      await CookieManager.instance().deleteCookies(
        url: WebUri('https://aiqicha.baidu.com'),
      );
      await CookieManager.instance().deleteCookies(
        url: WebUri('https://passport.baidu.com'),
      );
      _logger.i('Cookie 清除成功');
    } catch (e) {
      _logger.e('清除 Cookie 失败: $e');
    }
  }

  /// 仅从存储读取 Cookie（不设置到 WebView）
  Future<Map<String, String>> _readCookiesFromStorageOnly() async {
    try {
      final jsonStr = await _secureStorage.read(key: _cookieKey);
      if (jsonStr == null || jsonStr.isEmpty) return {};
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  /// 构建爱企查 Cookie 请求头
  String _buildAiqichaCookieHeader(Map<String, String> cookies) {
    final parts = <String>[];
    for (final entry in cookies.entries) {
      var name = entry.key;
      final value = entry.value;
      if (value.isEmpty) continue;
      if (name.startsWith('aiqicha_')) {
        name = name.substring('aiqicha_'.length);
      } else if (name.startsWith('passport_')) {
        name = name.substring('passport_'.length);
      }
      parts.add('$name=$value');
    }
    return parts.join('; ');
  }

  /// 解析爱企查搜索结果 HTML
  List<Enterprise> _parseAiqichaSearchHtml(String html) {
    final normalized = html.replaceAll('\n', ' ');

    // 匹配企业详情链接和名称
    final linkRe = RegExp(
      r'href="[^"]*?(?:company_detail|company_detail_.*?)\?[^"]*?pid=([^"&]+)[^"]*"[^>]*>(.*?)<',
      caseSensitive: false,
    );

    final seen = <String>{};
    final results = <Enterprise>[];

    for (final m in linkRe.allMatches(normalized)) {
      final pid = (m.group(1) ?? '').trim();
      var name = (m.group(2) ?? '').trim();
      name = _stripHtmlTags(name).trim();
      if (pid.isEmpty || name.isEmpty) continue;
      if (seen.contains(pid)) continue;
      seen.add(pid);

      results.add(
        Enterprise(
          id: pid,
          name: name,
          source: 'iqicha',
        ),
      );
    }

    return results;
  }

  /// 移除 HTML 标签
  String _stripHtmlTags(String input) {
    return input.replaceAll(RegExp(r'<[^>]+>'), '');
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
}
