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
        final result = EnterpriseSearchResult.fromJson(
          response.data as Map<String, dynamic>,
        );
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
        final message = errorData['message'] as String?;
        if (message != null) {
          return EnterpriseSearchResult.error(message);
        }
      }
      
      return EnterpriseSearchResult.error('搜索失败: ${e.message}');
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
}

/// Mock 企业仓库实现
///
/// 用于开发和测试
class MockEnterpriseRepository implements EnterpriseRepository {
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  final Map<String, String> _cookies = {};

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
